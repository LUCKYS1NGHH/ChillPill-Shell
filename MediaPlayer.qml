import Quickshell
import QtQuick
import Quickshell.Services.Mpris

Rectangle {
    id: mediaCard
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: mprisModule.hasPlayer ? 118 : 0
    radius: 12
    color: "#212121"
    visible: mprisModule.hasPlayer
    clip: true
    border.color: "#1d1d1d"
    border.width: 2

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
        anchors.margins: 14
        spacing: 15

        // top row -> art + info + controls
        Row {
            width: parent.width
            height: 48
            spacing: 15

            // album art
            Rectangle {
                width: 47; height: 47
                radius: 8
                color: "#2a2a2a"
                anchors.verticalCenter: parent.verticalCenter
                clip: true

                Image {
                    anchors.fill: parent
                    source: mprisModule.artUrl
                    fillMode: Image.PreserveAspectCrop
                    visible: mprisModule.artUrl !== ""
                    layer.enabled: true
                }

                Text {
                    anchors.centerIn: parent
                    visible: mprisModule.artUrl === ""
                    text: "\uf001"
                    font.family: "FiraCode Nerd Font Propo"
                    font.pixelSize: 18
                    color: "#555"
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
                    color: "#e8e8e8"
                    font.pixelSize: 12
                    font.bold: true
                    font.family: Theme.fontFamily
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: mprisModule.artist
                    color: "#656565"
                    font.pixelSize: 9
                    font.weight: 400
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
                    font.family: "FiraCode Nerd Font Propo"
                    font.pixelSize: 23
                    color: prevHover.containsMouse ? "#ffffff" : "#aeaeae"
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
                    font.family: "FiraCode Nerd Font Propo"
                    font.pixelSize: 23
                    color: playHover.containsMouse ? "#ffffff" : "#cdcdcd"
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
                    font.family: "FiraCode Nerd Font Propo"
                    font.pixelSize: 23
                    color: nextHover.containsMouse ? "#ffffff" : "#aeaeae"
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
                height: 3
                radius: 8
                color: "#4d4d4d"

                Rectangle {
                    width: parent.width * mediaCard.mprisProgress
                    height: parent.height
                    radius: 5
                    color: fg
                    Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.Linear } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
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
                    color: "#626262"
                    font.pixelSize: 10
                    font.family: Theme.fontFamily
                }

                Text {
                    anchors.right: parent.right
                    text: mediaCard.mprisTimeTotal
                    color: "#626262"
                    font.pixelSize: 10
                    font.family: Theme.fontFamily
                }
            }
        }
    }
}
