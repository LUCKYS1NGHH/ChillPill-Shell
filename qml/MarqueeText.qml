import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    property string icon: ""
    property color iconColor: label.color
    property string iconFontFamily: label.font.family
    property int iconPixelSize: label.font.pixelSize

    property alias text: label.text
    property alias color: label.color
    property alias font: label.font
    property int maxWidth: 50
    property int pauseDuration: 1000

    Text {
        visible: root.icon.length > 0
        text: root.icon
        color: root.iconColor
        font { family: root.iconFontFamily; pixelSize: root.iconPixelSize }
    }

    Item {
        id: textBox
        property bool overflowing: label.width > root.maxWidth && label.width > 0

        Layout.maximumWidth: root.maxWidth
        Layout.preferredWidth: implicitWidth
        implicitWidth: Math.min(label.width, root.maxWidth)
        implicitHeight: label.contentHeight
        clip: true

        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            verticalAlignment: Text.AlignVCenter

            Binding {
                target: label
                property: "x"
                value: (textBox.width - label.width) / 2
                when: !textBox.overflowing
                restoreMode: Binding.RestoreBindingOrValue
            }

            SequentialAnimation on x {
                running: textBox.overflowing
                loops: Animation.Infinite
                PauseAnimation { duration: root.pauseDuration }
                NumberAnimation { from: 0; to: -(label.width - root.maxWidth + 4); duration: Math.max(1500, label.width * 30); easing.type: Easing.InOutQuad }
                PauseAnimation { duration: root.pauseDuration }
                NumberAnimation { from: -(label.width - root.maxWidth + 4); to: 0; duration: Math.max(1500, label.width * 30); easing.type: Easing.InOutQuad }
            }
        }
    }
}
