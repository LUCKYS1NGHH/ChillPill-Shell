import QtQuick
import "../"

SRow {
    id: n
    property real value: 0
    property real from: 0
    property real to: 1e9
    property real step: 1
    property real divisor: 1
    property string suffix: ""
    property int decimals: 0
    property alias input: inp
    signal edited(real v)

    function clamp(v) { return Math.max(n.from, Math.min(n.to, v)) }
    function commit(shown) {
        var s = Number(shown)
        if (isNaN(s)) return
        n.edited(n.clamp(Math.round(s * n.divisor)))
    }

    Row {
        spacing: 6
        MiniBtn { label: "−"; onClicked: n.edited(n.clamp(n.value - n.step)) }
        Rectangle {
            width: 84; height: 28; radius: 6; color: Theme.bg1
            border.color: inp.activeFocus ? Theme.borderBgFocus : Theme.borderBg2
            TextInput {
                id: inp
                anchors.fill: parent
                anchors.margins: 6
                horizontalAlignment: TextInput.AlignHCenter
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.fg
                font.family: Theme.fontFamily
                selectByMouse: true
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                text: (n.value / n.divisor).toFixed(n.decimals)
                onEditingFinished: n.commit(text)
            }
        }
        MiniBtn { label: "+"; onClicked: n.edited(n.clamp(n.value + n.step)) }
        Text {
            visible: n.suffix !== ""
            text: n.suffix
            color: Theme.fg4
            font.family: Theme.fontFamily
            width: 28
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
