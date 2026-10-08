import QtQuick
import QtQuick.Layouts
import Quickshell
import "components"
import "pages"

// ChillPill Settings — standalone editor for chillpill-shell's config.jsonc
//
// The pieces this window is assembled from live next to it: config read/write
// is ConfigStore.qml, colours and fonts are Theme.qml, the reusable setting
// rows are under components/, and each sidebar section is a Page under pages/.
// The section order must match the `pages` list on the window below.

ShellRoot {
    id: root

    // ───────────────────────────── window ─────────────────────────────

    FloatingWindow {
        id: win
        title: "ChillPill Settings"
        color: Theme.bgD
        implicitWidth: 940
        implicitHeight: 660
        minimumSize: Qt.size(720, 480)
        visible: true

        property int current: 0
        // query from the sidebar; each page filters itself and counts the hits
        property string search: ""

        function matches(index) {
            var p = stack.children[index]
            return p && p.matchCount !== undefined ? p.matchCount : 0
        }
        // jump to a page that has hits; 0ms lets every page's filter settle
        onSearchChanged: jumpTimer.restart()
        Timer {
            id: jumpTimer
            interval: 0
            onTriggered: {
                if (win.search.trim() === "" || win.matches(win.current) > 0) return
                for (var i = 0; i < win.pages.length; i++)
                    if (win.matches(i) > 0) { win.current = i; return }
            }
        }
        // "/" summons the box; inert while focused so "/" can still be typed
        Shortcut {
            sequence: "/"
            enabled: !si.activeFocus
            onActivated: { si.forceActiveFocus(); si.selectAll() }
        }
        // fade the content in when switching sections; the sidebar highlight
        // already eases via its own color animation
        onCurrentChanged: pageFade.restart()
        NumberAnimation {
            id: pageFade
            target: stack
            property: "opacity"
            from: 0
            to: 1
            duration: 170
            easing.type: Easing.OutCubic
        }
        // icon codepoints verified present in the configured nerd font
        readonly property var pages: [
            { name: "Appearance",     icon: String.fromCodePoint(0xf03d8) }, // md-palette
            { name: "Pill",           icon: String.fromCodePoint(0xf0402) }, // md-pill
            { name: "Notifications",  icon: String.fromCodePoint(0xf0f3)  }, // fa-bell
            { name: "Media & OSD",    icon: String.fromCodePoint(0xf0387) }, // md-music_note
            { name: "Weather & Data", icon: String.fromCodePoint(0xf015f) }, // md-cloud
            { name: "System",         icon: String.fromCodePoint(0xf0493) }, // md-cog
            { name: "Dependencies",   icon: String.fromCodePoint(0xf21e)  }, // fa-heartbeat
            { name: "Wallpaper",      icon: String.fromCodePoint(0xf0e09) }  // md-wallpaper
        ]

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // sidebar
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 200
                color: Theme.bg
                ColumnLayout {
                    anchors.fill: parent
                    anchors.topMargin: 20
                    anchors.margins: 12
                    spacing: 4
                    // wordmark, aligned with the nav rows below
                    ColumnLayout {
                        Layout.leftMargin: 12
                        Layout.bottomMargin: 10
                        spacing: 1
                        Text {
                            text: "ChillPill"
                            color: Theme.fgL
                            font.family: Theme.fontFamily
                            font.pixelSize: 19
                            font.bold: true
                        }
                        Text {
                            text: "SETTINGS"
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.letterSpacing: 3
                        }
                    }
                    // one query filters every page; badges show the hits per page
                    Rectangle {
                        id: searchBox
                        Layout.fillWidth: true
                        height: 30
                        radius: 6
                        color: Theme.bg1
                        border.color: si.activeFocus ? Theme.borderBgFocus : Theme.borderBg2
                        Behavior on border.color { ColorAnimation { duration: 90 } }
                        // idle hint
                        Text {
                            id: hint
                            anchors.left: srow.left
                            anchors.leftMargin: sic.width + srow.spacing
                            anchors.verticalCenter: srow.verticalCenter
                            visible: si.text === "" && !si.activeFocus
                            text: "/ to search"
                            color: Theme.fg4
                            font.family: Theme.nerdFontFamily
                            font.pixelSize: 12
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { si.forceActiveFocus(); si.selectAll() }
                            }
                        }
                        RowLayout {
                            id: srow
                            anchors.fill: parent
                            anchors.leftMargin: 9
                            anchors.rightMargin: 8
                            spacing: 7
                            Text {
                                id: sic
                                text: String.fromCodePoint(0xf002) // fa-search
                                color: si.activeFocus ? Theme.accent : Theme.fg5
                                font.family: Theme.nerdFontFamily
                                font.pixelSize: 11
                            }
                            TextInput {
                                id: si
                                Layout.fillWidth: true
                                verticalAlignment: TextInput.AlignVCenter
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                selectByMouse: true
                                clip: true
                                // no text: binding; typing writes win.search directly
                                onTextChanged: win.search = text
                                // clear and unfocus
                                Keys.onEscapePressed: { si.text = ""; si.focus = false; event.accepted = true }
                            }
                            Text {
                                visible: si.text !== ""
                                text: "\u2715"
                                color: clrMa.containsMouse ? Theme.fg : Theme.fg5
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                MouseArea {
                                    id: clrMa
                                    anchors.fill: parent
                                    anchors.margins: -5
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { si.text = ""; si.focus = false }
                                }
                            }
                        }
                    }
                    Repeater {
                        model: win.pages
                        Rectangle {
                            id: nav
                            required property int index
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 38; radius: 8
                            color: win.current === nav.index ? Theme.bg5 : (nma.containsMouse ? Theme.bg2 : "transparent")
                            Behavior on color { ColorAnimation { duration: 90 } }
                            // dim pages the query misses
                            opacity: win.search !== "" && win.matches(nav.index) === 0 ? 0.35 : 1
                            Behavior on opacity { NumberAnimation { duration: 90 } }
                            Rectangle {
                                // active-page indicator
                                x: 2
                                width: 3; height: 20; radius: 1.5
                                anchors.verticalCenter: parent.verticalCenter
                                visible: win.current === nav.index
                                color: Theme.accent
                            }
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                x: 12
                                spacing: 10
                                Text {
                                    text: nav.modelData.icon
                                    color: win.current === nav.index ? Theme.fg : Theme.fg3
                                    font.family: Theme.nerdFontFamily
                                    font.pixelSize: 14
                                }
                                Text {
                                    text: nav.modelData.name
                                    color: win.current === nav.index ? Theme.fg : Theme.fg3
                                    font.family: Theme.fontFamily
                                }
                            }
                            // hits on this page
                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                visible: win.search !== "" && win.matches(nav.index) > 0
                                text: win.matches(nav.index)
                                color: Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                            }
                            MouseArea {
                                id: nma
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.current = nav.index
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.bg3
                        Layout.topMargin: 8
                        Layout.bottomMargin: 8
                    }
                    Text {
                        text: ConfigStore.configPath
                        color: Theme.fg5
                        font.family: Theme.nerdFontFamily
                        font.pixelSize: 10
                        wrapMode: Text.WrapAnywhere
                        Layout.fillWidth: true
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 6
                        Text { text: ConfigStore.status; color: ConfigStore.statusError ? Theme.deleting : Theme.fg3; font.family: Theme.fontFamily; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight }
                        MiniBtn { label: ""; onClicked: ConfigStore.reload(); fontSize: 15; rectRadius: 8 }
                    }
                }
            }

            // content
            StackLayout {
                id: stack
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: win.current
                enabled: ConfigStore.loaded

                AppearancePage { filter: win.search }
                PillPage { filter: win.search }
                NotificationsPage { filter: win.search }
                MediaOsdPage { filter: win.search }
                WeatherDataPage { filter: win.search }
                SystemPage { filter: win.search }
                HealthPage { filter: win.search }
                WallpaperPage { filter: win.search }
            }
        }
    }
}
