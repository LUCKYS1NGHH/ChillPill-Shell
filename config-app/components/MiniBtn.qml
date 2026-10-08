import QtQuick
import "../"

Rectangle {
    id: b
    property string label: ""
    property int fontSize: 12
    property bool textBold: false
    property int rectRadius: 6
    signal clicked()
    width: 26; height: 26; radius: rectRadius
    color: ma.containsMouse ? Theme.bg8 : Theme.bg6
    Text { anchors.centerIn: parent; text: b.label; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: fontSize; font.bold: textBold; }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: b.clicked()
    }
}
