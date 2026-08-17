import Quickshell
import Quickshell.Widgets
import QtQuick
import Quickshell.Services.Mpris

Rectangle {
    id: mediaCard
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: mprisModule.hasPlayer ? 118 : 0
    radius: 16
    color: Theme.bgD
    visible: mprisModule.hasPlayer
    clip: true
    border.color: Theme.borderBg3
    border.width: 1

    property int margin: 14

    // artist name adjustments
    property int artistFontSize: 10
    property string artistFontColor: Theme.fg4
    property int artistFontWeight: 300

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

    // interpolate every second
    Timer {
        id: progressPoller
        interval: 1000
        running: box.controlCenter && mprisModule.hasPlayer
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            mediaCard.mprisProgress = mprisModule.progress
            mediaCard.mprisTimePlayed = mediaCard.formatMprisTime(mprisModule.polledPosition)
            mediaCard.mprisTimeTotal = mediaCard.formatMprisTime(mprisModule.polledLength)
        }
    }

     Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 15

        // top row -> art + info + controls
        Row {
            width: parent.width
            height: 48
            spacing: 15

            // album art
            ClippingRectangle {
                width: 47; height: 47
                radius: 7
                color: "transparent"
                anchors.verticalCenter: parent.verticalCenter
                clip: true

                Image {
                    anchors.fill: parent
                    source: mprisModule.artUrl
                    fillMode: Image.PreserveAspectCrop
                    visible: mprisModule.artUrl !== ""
                    layer.enabled: true
                    cache: false
                    sourceSize: Qt.size(94 * box.dpi, 94 * box.dpi)
                }

                Text {
                    anchors.centerIn: parent
                    visible: mprisModule.artUrl === ""
                    text: "\uf001"
                    font.family: Theme.nerdFontFamily
                    font.pixelSize: 18
                    color: Theme.fg4
                }
            }

            // track + artist
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 46 - 90 - 24
                spacing: 4

                Text {
                    width: parent.width
                    text: mprisModule.track !== "" ? mprisModule.track : "Nothing playing"
                    color: Theme.fgL
                    font.pixelSize: 12
                    font.weight: 600
                    font.family: Theme.fontFamily
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: mprisModule.artist
                    color: artistFontColor
                    font.pixelSize: artistFontSize
                    font.weight: artistFontWeight
                    font.family: Theme.fontFamily
                    elide: Text.ElideRight
                }
            }

            // controls
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14

                Text {
                    text: "⏮"
                    font.family: Theme.nerdFontFamily
                    font.pixelSize: 23
                    color: prevHover.containsMouse ? "white" : Theme.fg3
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 100 } }
                    MouseArea {
                        id: prevHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { mprisModule.prev() }
                    }
                }

                Text {
                    text: mprisModule.playing ? "󰏤" : "󰐊"
                    font.family: Theme.nerdFontFamily
                    font.pixelSize: 23
                    color: playHover.containsMouse ? "white" : Theme.fg2
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 100 } }
                    MouseArea {
                        id: playHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mprisModule.playPause()
                    }
                }

                Text {
                    text: "⏭"
                    font.family: Theme.nerdFontFamily
                    font.pixelSize: 23
                    color: nextHover.containsMouse ? "white" : Theme.fg3
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 100 } }
                    MouseArea {
                        id: nextHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mprisModule.next()
                    }
                }
            }
        }

        // progress bar + time
        Column {
            width: parent.width
            spacing: 8

            Rectangle {
                width: parent.width
                height: barHover.containsMouse ? 5 : 3
                radius: 8
                color: Theme.bg5

                Behavior on height { NumberAnimation { duration: 380; easing.type: Easing.OutExpo } }

                Rectangle {
                    width: parent.width * mediaCard.mprisProgress
                    height: parent.height
                    radius: 5
                    color: barHover.containsMouse ? Theme.fgL : fg
                    Behavior on width { NumberAnimation { duration: 510; easing.type: Easing.Linear } }
                }

                MouseArea {
                    id: barHover
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: (mouse) => {
                        let p = mprisModule.activePlayer
                        if (!p || !p.length) return
                        let ratio = mouse.x / width
                        let len = Number(p.length) || 0
                        if (len <= 0 && p.metadata && p.metadata["mpris:length"])
                            len = Number(p.metadata["mpris:length"])
                        if (len > 0) p.position = ratio * len
                    }
                }
            }

            Item {
                width: parent.width
                height: 10

                Text {
                    anchors.left: parent.left
                    text: mediaCard.mprisTimePlayed
                    color: Theme.fg5
                    font.pixelSize: 10
                    font.family: Theme.fontFamily
                }

                Text {
                    anchors.right: parent.right
                    text: mediaCard.mprisTimeTotal
                    color: Theme.fg5
                    font.pixelSize: 10
                    font.family: Theme.fontFamily
                }
            }
        }
    }
}
