import QtQuick
import "../"

SRow {
    id: t
    property bool value: false
    signal edited(bool v)
    Rectangle {
        width: 40; height: 22; radius: 15
        color: t.value ? Theme.accent : (tMa.containsMouse ? Theme.bg8 : Theme.bg5)
        border.width: 1
        border.color: t.value ? "transparent" : Theme.borderBg2
        Behavior on color { ColorAnimation { duration: 100 } }
        Behavior on border.color { ColorAnimation { duration: 100 } }
        Rectangle {
            id: knob
            width: tMa.pressed ? 20 : 16
            height: 16
            radius: knob.width / 2
            y: 3
            x: t.value ? parent.width - knob.width - 3 : 3
            color: Theme.fgL
            border.width: 1
            border.color: Theme.borderBg
            Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }
        MouseArea {
            id: tMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: t.edited(!t.value)
        }
    }
}
