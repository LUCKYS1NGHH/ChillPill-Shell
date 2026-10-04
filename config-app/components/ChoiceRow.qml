import QtQuick
import "../"

SRow {
    id: c
    property var options: []
    property string value: ""
    signal edited(string v)
    Row {
        spacing: 4
        Repeater {
            model: c.options
            Rectangle {
                id: opt
                required property string modelData
                width: lbl.implicitWidth + 24; height: 30; radius: 6
                color: opt.modelData === c.value ? Theme.accent : (optMa.containsMouse ? Theme.bg8 : Theme.bg6)
                Text {
                    id: lbl
                    anchors.centerIn: parent
                    text: opt.modelData
                    color: opt.modelData === c.value ? Theme.bgD : Theme.fg
                    font.family: Theme.fontFamily
                }
                MouseArea {
                    id: optMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: c.edited(opt.modelData)
                }
            }
        }
    }
}
