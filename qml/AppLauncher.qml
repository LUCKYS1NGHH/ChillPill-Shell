import Quickshell
import QtQuick
import QtQuick.Layouts
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

    // shrinks with results, capped at original max height (~387px / 302px list)
    property int rowHeight: 44
    property int rowSpacing: 2
    property int headerHeight: 15
    property int maxListHeight: 302
    readonly property int listHeight: root.filteredApps.length === 0
        ? root.rowHeight
        : Math.min(root.filteredApps.length * root.rowHeight + (root.filteredApps.length - 1) * root.rowSpacing, root.maxListHeight)
    readonly property int baseHeight: 12 + root.headerHeight + 8 + 30 + 8 + 12
    height: root.baseHeight + root.listHeight
    Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    visible: opacity > 0
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    scale: shown ? 1 : 0.96
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    property var filteredApps: searchQuery.length === 0
        ? appsCache
        : appsCache.filter(a =>
            a.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
            a.comment.toLowerCase().includes(searchQuery.toLowerCase()))

    onFilteredAppsChanged: selectedIndex = 0

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
            searchInput.forceActiveFocus()
        }
    }

    function loadApps() {
        let list = []
        let entries = DesktopEntries.applications.values
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

    Rectangle {
        anchors.fill: parent
        radius: 19
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

          Text {
              id: listCountText
              property int total: 0
              text: (filteredApps.count === 0 ? 0 : root.selectedIndex + 1)
                     + " / " + appList.count + " (" + appList.count + ")"
              color: Theme.fg4
              font { family: Theme.fontFamily; pixelSize: 9; weight: 300 }
              Layout.alignment: Qt.AlignRight
              Layout.rightMargin: 6
            }
        }

        Rectangle {
            width: parent.width
            height: 30
            radius: 8
            color: Theme.bg4
            border.color: searchInput.activeFocus ? Theme.borderBgFocus : Theme.borderBg
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: 120 } }

            TextInput {
                id: searchInput
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.fg
                font { family: Theme.fontFamily; pixelSize: 11 }
                clip: true

                onTextChanged: root.searchQuery = text

                Text {
                    text: "search apps..."
                    color: Theme.fg4
                    font: searchInput.font
                    visible: searchInput.text.length === 0
                    anchors.verticalCenter: parent.verticalCenter
                }

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Down) {
                        if (root.filteredApps.length > 0)
                            root.selectedIndex = (root.selectedIndex + 1) % root.filteredApps.length
                        appList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Up) {
                        if (root.filteredApps.length > 0)
                            root.selectedIndex = root.selectedIndex <= 0
                                ? root.filteredApps.length - 1
                                : root.selectedIndex - 1
                        appList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
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
            highlightMoveDuration: 80
            spacing: 2

            highlight: Rectangle {
                x: 2
                y: appList.currentItem ? appList.currentItem.y : -999
                width: appList.width - 4
                height: appList.currentItem ? appList.currentItem.height : 44
                radius: 9
                color: Theme.bgD
                Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            }

            delegate: Rectangle {
                id: rowDelegate
                width: appList.width
                height: 44
                radius: 9
                color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 10
                    spacing: 10

                    IconImage {
                        id: appIcon
                        visible: Quickshell.iconPath(modelData.icon, true)
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        Layout.alignment: Qt.AlignVCenter
                        source: Quickshell.iconPath(modelData.icon, true)
                        asynchronous: false
                        scale: index === root.selectedIndex ? 1.10 : 1
                        Behavior on scale { NumberAnimation { duration: 350; easing.type: Easing.OutQuad } }
                    }

                    Text {
                        visible: !Quickshell.iconPath(modelData.icon, true)
                        text: "?"
                        color: Theme.fg
                        font { family: Theme.fontFamily; pixelSize: 12; weight: 700 }
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: 8
                        Layout.rightMargin: 10
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: modelData.name
                            color: Theme.fg
                            font { family: Theme.fontFamily; pixelSize: 11; weight: index === root.selectedIndex ? 600 : 500 }
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: modelData.comment
                            visible: text.length > 0
                            color: Theme.fg5
                            font { family: Theme.fontFamily; pixelSize: 9; weight: 500 }
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }

                MouseArea {
                    id: rowHover
                    property bool hovered: false
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: {
                        hovered = true
                        root.selectedIndex = index
                    }
                    onExited: hovered = false
                    onClicked: {
                        root.selectedIndex = index
                        root.launchSelected()
                    }
                }
              }

            Text {
                anchors.centerIn: parent
                visible: appList.count === 0
                text: "No apps found"
                color: Theme.fg3
                font { family: Theme.fontFamily; pixelSize: 10 }
            }
        }
    }
}
