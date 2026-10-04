import QtQuick
import "../"

SRow {
    id: t
    property bool value: false
    signal edited(bool v)
    Rectangle {
        width: 46; height: 26; radius: 13
        color: t.value ? Theme.accent : (tMa.containsMouse ? Theme.bg8 : Theme.bg6)
        border.width: 1
        border.color: t.value ? "transparent" : Theme.borderBg3
        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }
        Rectangle {
            id: knob
            width: tMa.pressed ? 24 : 20
            height: 20
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
