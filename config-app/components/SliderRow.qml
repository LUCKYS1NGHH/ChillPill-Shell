import QtQuick
import "../"

SRow {
    id: s
    property real value: 0
    property real from: 0
    property real to: 1
    property real step: 0.05
    property int decimals: 2
    signal edited(real v)
    readonly property real frac: Math.max(0, Math.min(1, (value - from) / (to - from)))

    Row {
        spacing: 14
        Item {
            id: track
            width: 200; height: 24
            Rectangle {
                id: bar
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 4; radius: 4; color: Theme.bg5
                Rectangle {
                    width: parent.width * s.frac
                    height: parent.height
                    radius: parent.radius
                    color: Theme.sliderBg
                    Behavior on width {
                        SpringAnimation { spring: 15.5; damping: 1.8; epsilon: 0.40 }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.topMargin: -8; anchors.bottomMargin: -8
                    cursorShape: Qt.PointingHandCursor
                    function upd(mx) {
                        var f = Math.max(0, Math.min(1, mx / bar.width))
                        var v = s.from + f * (s.to - s.from)
                        v = Math.round(v / s.step) * s.step
                        s.edited(Number(v.toFixed(s.decimals)))
                    }
                    onClicked: (mouse) => upd(mouse.x)
                    onPositionChanged: (mouse) => { if (pressed) upd(mouse.x) }
                }
            }
        }
        Text {
            text: s.value.toFixed(s.decimals)
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: 10
            width: Math.max(35, implicitWidth)
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
