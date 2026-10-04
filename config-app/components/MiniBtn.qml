import QtQuick
import "../"

Rectangle {
    id: b
    property string label: ""
    signal clicked()
    width: 28; height: 28; radius: 6
    color: ma.containsMouse ? Theme.bg8 : Theme.bg6
    Text { anchors.centerIn: parent; text: b.label; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: 12 }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: b.clicked()
    }
}
