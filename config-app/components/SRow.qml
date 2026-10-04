import QtQuick
import QtQuick.Layouts
import "../"

Rectangle {
    id: r
    property string label: ""
    property string hint: ""
    default property alias content: slot.data
    Layout.fillWidth: true
    implicitHeight: hint ? 62 : 52
    color: "transparent"

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: slot.left
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Text { text: r.label; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight }
        Text { visible: r.hint !== ""; text: r.hint; color: Theme.fg4; font.family: Theme.fontFamily; font.pixelSize: 10; Layout.fillWidth: true; elide: Text.ElideRight }
    }
    Item {
        id: slot
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: childrenRect.height
    }
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.bg3 }
}
