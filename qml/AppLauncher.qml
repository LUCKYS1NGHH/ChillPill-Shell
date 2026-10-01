import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Widgets

Item {
    id: root
    clip: true

    property bool shown: false
    property int selectedIndex: 0
    property string searchQuery: ""
    property var appsCache: []

    signal closeRequested()

    width: 315

    property int rowHeight: 40
    property int rowSpacing: 2
    property int headerHeight: 15
    property int maxListHeight: 250
    readonly property int listHeight: root.filteredApps.length === 0
        ? root.rowHeight
        : Math.min(root.filteredApps.length * root.rowHeight + (root.filteredApps.length - 1) * root.rowSpacing, root.maxListHeight)
    readonly property int baseHeight: 12 + root.headerHeight + 8 + 30 + 8 + 12
    height: root.baseHeight + root.listHeight
    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    // open/close: fade + gentle scale that grows down from the top edge
    visible: opacity > 0
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    transformOrigin: Item.Top
    scale: shown ? 1 : 0.94
    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    // name-prefix matches first, then name-contains, then comment-only
    property var filteredApps: {
        if (searchQuery.length === 0) return appsCache
        const q = searchQuery.toLowerCase()
        let starts = [], contains = [], comment = []
        for (let i = 0; i < appsCache.length; i++) {
            const a = appsCache[i]
            const n = a.name.toLowerCase()
            if (n.startsWith(q)) starts.push(a)
            else if (n.includes(q)) contains.push(a)
            else if (a.comment.toLowerCase().includes(q)) comment.push(a)
        }
        return starts.concat(contains, comment)
    }

    onFilteredAppsChanged: selectedIndex = 0

    // keep the selection visible when moved by keyboard / on reset
    onSelectedIndexChanged: if (keyboardNav) appList.positionViewAtIndex(selectedIndex, ListView.Contain)
    property bool keyboardNav: false

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            if (root.appsCache.length === 0 || root.shown) loadApps()
        }
    }

    onShownChanged: {
        if (shown) {
            loadApps()
            searchQuery = ""
            searchInput.text = ""
            selectedIndex = 0
            appList.positionViewAtBeginning()
            searchInput.forceActiveFocus()
        }
    }

    Component.onCompleted: loadApps()

    function loadApps() {
        let entries = DesktopEntries.applications ? DesktopEntries.applications.values : []
        let list = []
        for (let i = 0; i < entries.length; i++) {
            let e = entries[i]
            list.push({
                name: e.name,
                comment: e.comment || "",
                icon: e.icon,
                entry: e
            })
        }
        list.sort((a, b) => a.name.localeCompare(b.name))
        appsCache = list
    }

    function launchSelected() {
        if (filteredApps.length === 0) return
        const app = filteredApps[selectedIndex].entry
        if (app.runInTerminal) {
            if (!Config.defaultTerminal || Config.defaultTerminal.length === 0) {
                console.log("No defaultTerminal configured, cannot launch this terminal app:", app.name)
                return
            }
            Quickshell.execDetached([Config.defaultTerminal, "-e", "sh", "-c", app.command.join(" ")])
        } else {
            app.execute()
        }
        root.closeRequested()
    }

    // bold the matched part of the name (escaped for StyledText)
    function esc(s) { return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;") }
    function highlightName(name, q) {
        if (!q || q.length === 0) return esc(name)
        const i = name.toLowerCase().indexOf(q.toLowerCase())
        if (i < 0) return esc(name)
        return esc(name.slice(0, i)) + "<b>" + esc(name.slice(i, i + q.length)) + "</b>" + esc(name.slice(i + q.length))
    }

    Rectangle {
        anchors.fill: parent
        radius: 22
        color: Theme.bgD1
        border.color: Theme.borderBg2
        border.width: 1
    }

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
            width: parent.width

            Text {
                text: "Applications"
                color: Theme.fg
                font { family: Theme.fontFamily; pixelSize: 12; weight: 700 }
                Layout.alignment: Qt.AlignLeft
                Layout.leftMargin: 5
            }

            Item { Layout.fillWidth: true }

            Text {
                text: root.filteredApps.length === 0
                    ? "0 / 0"
                    : (root.selectedIndex + 1) + " / " + root.filteredApps.length
                color: Theme.fg4
                font { family: Theme.fontFamily; pixelSize: 9; weight: 300 }
                Layout.alignment: Qt.AlignRight
                Layout.rightMargin: 6
            }
        }

        Rectangle {
            id: searchBox
            width: parent.width
            height: 30
            radius: 8
            color: Theme.bg3
            border.color: searchInput.activeFocus ? Theme.borderBgFocus : Theme.borderBg
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: 120 } }

            // subtle "breathing" scale on focus
            scale: searchInput.activeFocus ? 1.0 : 0.985
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            TextInput {
                id: searchInput
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 28
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.fg
                font { family: Theme.fontFamily; pixelSize: 11 }
                clip: true
                selectByMouse: true

                onTextChanged: root.searchQuery = text

                Text {
                    text: "search apps..."
                    color: Theme.fg3
                    font: searchInput.font
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: searchInput.text.length === 0 ? 1 : 0
                    x: searchInput.text.length === 0 ? 0 : 6
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                    Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                }

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Down) {
                        root.keyboardNav = true
                        if (root.filteredApps.length > 0)
                            root.selectedIndex = (root.selectedIndex + 1) % root.filteredApps.length
                        event.accepted = true
                    } else if (event.key === Qt.Key_Up) {
                        root.keyboardNav = true
                        if (root.filteredApps.length > 0)
                            root.selectedIndex = root.selectedIndex <= 0
                                ? root.filteredApps.length - 1
                                : root.selectedIndex - 1
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.launchSelected()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Escape) {
                        root.closeRequested()
                        event.accepted = true
                    }
                }
            } 
        }

        ListView {
            id: appList
            width: parent.width
            height: root.listHeight
            clip: true
            model: root.filteredApps
            currentIndex: root.selectedIndex
            highlightFollowsCurrentItem: false
            spacing: root.rowSpacing
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                implicitWidth: 3
                background: Item {}
                contentItem: Rectangle {
                    implicitWidth: 3
                    radius: 2
                    color: Theme.fg4
                    opacity: parent.active ? 0.7 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }
            }

            // sliding selection pill with a slight overshoot
            highlight: Rectangle {
                x: 2
                y: appList.currentItem ? appList.currentItem.y : -999
                width: appList.width - 4
                height: appList.currentItem ? appList.currentItem.height : root.rowHeight
                radius: 9
                color: Theme.bgD
                Behavior on y {
                    NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
                }
            }

            delegate: Rectangle {
                id: rowDelegate
                width: appList.width
                height: root.rowHeight
                radius: 9
                color: "transparent"

                readonly property bool selected: index === root.selectedIndex
                readonly property var iconSrc: Quickshell.iconPath(modelData.icon, true)

                // staggered reveal: fade + slide up, capped so long lists don't lag
                property real reveal: 0
                opacity: reveal
                transform: Translate { y: (1 - rowDelegate.reveal) * 8 }

                SequentialAnimation {
                    id: revealAnim
                    PauseAnimation { duration: Math.min(index, 9) * 22 }
                    NumberAnimation {
                        target: rowDelegate; property: "reveal"
                        from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic
                    }
                }
                Component.onCompleted: revealAnim.start()

                Connections {
                    target: root
                    function onShownChanged() {
                        if (root.shown) {
                            rowDelegate.reveal = 0
                            revealAnim.restart()
                        }
                    }
                }

                // press feedback
                scale: rowHover.pressed ? 0.98 : 1
                Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 10
                    spacing: 10

                    IconImage {
                        id: appIcon
                        visible: !!rowDelegate.iconSrc
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        Layout.alignment: Qt.AlignVCenter
                        source: rowDelegate.iconSrc
                        asynchronous: false
                        scale: rowDelegate.selected ? 1.10 : 1
                        rotation: rowDelegate.selected ? -4 : 0
                        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
                        Behavior on rotation { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                    }

                    // fallback glyph in a soft circle when the icon is missing
                    Rectangle {
                        visible: !rowDelegate.iconSrc
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        Layout.alignment: Qt.AlignVCenter
                        radius: 13
                        color: Theme.bg4
                        Text {
                            anchors.centerIn: parent
                            text: modelData.name.length > 0 ? modelData.name[0].toUpperCase() : "?"
                            color: Theme.fg
                            font { family: Theme.fontFamily; pixelSize: 12; weight: 700 }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: root.highlightName(modelData.name, root.searchQuery)
                            textFormat: Text.StyledText
                            color: Theme.fg
                            font { family: Theme.fontFamily; pixelSize: 11; weight: rowDelegate.selected ? 600 : 500 }
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            // nudge selected text right a touch
                            Layout.leftMargin: rowDelegate.selected ? 2 : 0
                            Behavior on Layout.leftMargin { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        }
                        Text {
                            text: modelData.comment
                            visible: text.length > 0
                            color: Theme.fg4
                            font { family: Theme.fontFamily; pixelSize: 9; weight: 500 }
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            Layout.leftMargin: rowDelegate.selected ? 2 : 0
                            Behavior on Layout.leftMargin { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        }
                    }
                }

                MouseArea {
                    id: rowHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: {
                        root.keyboardNav = false
                        root.selectedIndex = index
                    }
                    onClicked: {
                        root.selectedIndex = index
                        root.launchSelected()
                    }
                }
            }

            // empty state
            Text {
                anchors.centerIn: parent
                text: "No apps found"
                color: Theme.fg3
                font { family: Theme.fontFamily; pixelSize: 10 }
                opacity: root.filteredApps.length === 0 ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 180 } }
            }
        }
    }
}
