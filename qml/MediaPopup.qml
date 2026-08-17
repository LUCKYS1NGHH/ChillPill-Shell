import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: root
    property bool active: false
    anchors.centerIn: parent
    width: 295
    height: 70
    opacity: active ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 180 } }

    property real mprisProgress: 0
    property string mprisTimePlayed: "0:00"
    property string mprisTimeTotal: "0:00"

    function formatMprisTime(val) {
        let n = Number(val)
        if (isNaN(n) || n <= 0) return "0:00"
        let m = Math.floor(n / 60)
        let s = Math.floor(n % 60)
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    Timer {
        interval: 500
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.mprisProgress = mprisModule.progress
            root.mprisTimePlayed = root.formatMprisTime(mprisModule.polledPosition)
            root.mprisTimeTotal = root.formatMprisTime(mprisModule.polledLength)
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 15

        // album art
        ClippingRectangle {
            id: artFrame
            Layout.preferredWidth: 38
            Layout.preferredHeight: 38
            radius: 8
            color: Theme.bg1
            clip: true

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: mprisModule.artUrl !== ""
                shadowColor: Theme.coverArtGlowShadow
                shadowBlur: 2.6
                shadowOpacity: 0.8
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
            }

            Image {
                anchors.fill: parent
                source: mprisModule.artUrl
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(84 * box.dpi, 84 * box.dpi)
              }

            Text {
                anchors.centerIn: parent
                visible: mprisModule.artUrl === ""
                text: "\uf001"
                font.family: Theme.nerdFontFamily
                font.pixelSize: 18
                color: Theme.fg5
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 3

            Text {
                text: mprisModule.track !== "" ? mprisModule.track : "Nothing playing"
                color: Theme.fgL
                font { family: Theme.fontFamily; pixelSize: 11; weight: 700 }
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: mprisModule.artist
                color: Theme.fg3D
                font { family: Theme.fontFamily; pixelSize: 9 }
                elide: Text.ElideRight
                Layout.fillWidth: true
                visible: text !== ""
            }

            // progress + time
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 5
                spacing: 8

                Text {
                    text: root.mprisTimePlayed
                    color: Theme.fg5
                    font { family: Theme.fontFamily; pixelSize: 8 }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 3
                    radius: 5
                    color: Theme.fg8

                    Rectangle {
                        width: parent.width * root.mprisProgress
                        height: parent.height
                        radius: 5
                        color: Theme.fg
                        Behavior on width { NumberAnimation { duration: 450; easing.type: Easing.Linear } }
                    }
                }

                Text {
                    text: root.mprisTimeTotal
                    color: Theme.fg5
                    font { family: Theme.fontFamily; pixelSize: 8 }
                }
            }
        }

        // play/pause button
        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            width: 25; height: 25; radius: 15
            color: playHover.containsMouse ? Theme.focusBg : Theme.bg3
            border.color: Theme.borderBg2
            border.width: 1
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: mprisModule.playing ? "󰏤" : "󰐊"
                font.family: Theme.nerdFontFamily
                font.pixelSize: 13
                color: Theme.fg
            }

            MouseArea {
                id: playHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: mprisModule.playPause()
            }
        }
    }
}
