import QtQuick
import "../"

SRow {
    id: tr
    property string value: ""
    property string placeholder: ""
    property int fieldWidth: 280
    property alias input: ti
    signal edited(string v)
    Rectangle {
        width: tr.fieldWidth; height: 32; radius: 6; color: Theme.bg1
        border.color: ti.activeFocus ? Theme.borderBgFocus : Theme.borderBg2
        TextInput {
            id: ti
            anchors.fill: parent
            anchors.margins: 8
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.fg
            font.family: Theme.fontFamily
            selectByMouse: true
            clip: true
            text: tr.value
            onEditingFinished: tr.edited(text)
        }
        Text {
            anchors.fill: parent
            anchors.margins: 8
            verticalAlignment: Text.AlignVCenter
            visible: ti.text === "" && !ti.activeFocus
            text: tr.placeholder
            color: Theme.fg6
            font.family: Theme.fontFamily
        }
    }
}
