import QtQuick
import QtQuick.Layouts
import "components"
import "."

ColumnLayout {
    id: nc
    property var value: []
    property string suffix: ""
    signal edited(var v)
    Layout.fillWidth: true

    Flow {
        Layout.fillWidth: true
        spacing: 6
        Repeater {
            model: nc.value
            Rectangle {
                id: nchip
                required property int index
                required property var modelData
                width: nl.implicitWidth + 40; height: 30; radius: 15
                color: Theme.bg2
                Text { id: nl; x: 12; anchors.verticalCenter: parent.verticalCenter; text: nchip.modelData + nc.suffix; color: Theme.fg; font.family: Theme.fontFamily }
                Text {
                    anchors.right: parent.right; anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "✕"; color: Theme.fg5
                    font.family: Theme.fontFamily
                    MouseArea {
                        anchors.fill: parent; anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { var a = nc.value.slice(); a.splice(nchip.index, 1); nc.edited(a) }
                    }
                }
            }
        }
        Rectangle {
            width: addHint.implicitWidth + 32; height: 30; radius: 15; color: Theme.bg1
            border.color: ni.activeFocus ? Theme.borderBgFocus : Theme.borderBg2
            TextInput {
                id: ni
                anchors.fill: parent
                anchors.leftMargin: 16; anchors.rightMargin: 16
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.fg
                font.family: Theme.fontFamily
                inputMethodHints: Qt.ImhDigitsOnly
                onAccepted: {
                    var v = Number(text)
                    if (!isNaN(v) && v > 0 && nc.value.indexOf(v) < 0)
                        nc.edited(nc.value.concat([v]).sort((a, b) => a - b))
                    text = ""
                }
            }
            Text {
                id: addHint
                anchors.fill: parent
                anchors.leftMargin: 16
                verticalAlignment: Text.AlignVCenter
                visible: ni.text === "" && !ni.activeFocus
                text: "add + Enter"
                color: Theme.fg6
                font.family: Theme.fontFamily
            }
        }
    }
    Text {
        Layout.fillWidth: true
        visible: nc.value.length === 0
        text: "No presets — type a number and press Enter"
        color: Theme.fg6
        font.family: Theme.fontFamily
    }
}
