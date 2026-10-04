import QtQuick
import "../"

Rectangle {
    id: fb
    property string label: ""
    property bool primary: false
    signal clicked()

    implicitWidth: lbl.implicitWidth + 26
    height: 28; radius: 6
    color: fb.primary ? Theme.accent : (fbMa.containsMouse ? Theme.bg4 : Theme.bg2)
    Text {
        id: lbl
        anchors.centerIn: parent
        text: fb.label
        color: fb.primary ? Theme.bgD : (fbMa.containsMouse ? Theme.fg : Theme.fg4)
        font.family: Theme.fontFamily
    }
    MouseArea {
        id: fbMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: fb.clicked()
    }
}
