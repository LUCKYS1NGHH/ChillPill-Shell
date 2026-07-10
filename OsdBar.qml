import QtQuick
import QtQuick.Layouts

Item {
    id: root

    // inputs
    property string iconColor: ""
    property bool active: false
    property string icon: ""
    property real percent: 0 // 0.0 - 1.0
    property string valueText: "" // e.g. "muted" or "72%" or "charging"
    property color fg: Theme.fg
    property color mutedFg: fg
    property bool muted: false
    property int spacing: 10
    property int defaultSpacing: spacing !== 0 ? spacing : 10

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
        spacing: defaultSpacing

        Text {
            text: root.icon
            color: root.iconColor !== "" ? root.iconColor : root.fg
            font { family: Theme.nerdFontFamily; pixelSize: 15 }
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
