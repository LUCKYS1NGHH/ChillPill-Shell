import QtQuick
import "../"

Rectangle {
    id: cb
    property string label: ""
    property bool dim: false
    property bool danger: false
    signal clicked()
    readonly property bool hovered: cma.containsMouse

    width: 20; height: 22; radius: 5
    color: cma.containsMouse ? (cb.danger ? Theme.bgD1 : Theme.bg6) : "transparent"
    Text {
        anchors.centerIn: parent
        text: cb.label
        color: cb.dim ? Theme.fg8 : (cb.danger ? Theme.deleting : Theme.fg4)
        font.family: Theme.fontFamily
        font.pixelSize: 11
        Behavior on color { ColorAnimation { duration: 90 } }
    }
    MouseArea {
        id: cma
        anchors.fill: parent
        enabled: !cb.dim
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: cb.clicked()
    }
}
