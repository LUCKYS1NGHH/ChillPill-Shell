import QtQuick
import QtQuick.Layouts

Item {
    id: root

    // inputs
    property bool active: false
    property string icon: ""
    property real percent: 0 // 0.0 - 1.0
    property string valueText: "" // e.g. "muted" or "72%"
    property color fg: Theme.fg
    property color mutedFg: fg
    property bool muted: false

    // bar adjustments
    property int barWidth: osdInWidth
    property real barHeight: osdInHeight
    property int barRadius: osdBarRadius
    property int fillSpeed: osdSpeed

    anchors.centerIn: parent
    opacity: active ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 150 } }

    RowLayout {
        anchors.centerIn: parent
        spacing: 10

        Text {
            text: root.icon
            color: root.muted ? root.mutedFg : root.fg
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 15 }
        }

        Rectangle {
            width: root.barWidth; height: root.barHeight
            radius: root.barRadius
            color: "#333"

            Rectangle {
                width: parent.width * root.percent
                height: parent.height
                radius: 2
                color: root.fg
                Behavior on width { NumberAnimation { duration: root.fillSpeed } }
            }
        }

        Text {
            text: root.valueText
            color: root.muted ? root.mutedFg : root.fg
            font { family: Theme.fontFamily; pixelSize: 10; weight: 600 }
        }
    }
}
