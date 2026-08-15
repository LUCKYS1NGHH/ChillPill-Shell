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
            id: valIcon
            text: root.icon
            color: root.iconColor !== "" ? root.iconColor : root.fg
            font { family: Theme.nerdFontFamily; pixelSize: 15 }
            opacity: 1.0
            onTextChanged: iconPulse.restart()
            SequentialAnimation {
                id: iconPulse
                NumberAnimation { target: valIcon; property: "opacity"; to: 0.5; duration: 100; easing.type: Easing.InOutQuad }
                NumberAnimation { target: valIcon; property: "opacity"; to: 1.0; duration: 140; easing.type: Easing.InOutQuad }
            }
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
          id: valText
          text: root.valueText
          color: root.muted ? root.mutedFg : root.fg
          font { family: Theme.fontFamily; pixelSize: 10; weight: 600 }
          opacity: 1.0
          onTextChanged: valPulse.restart()
          SequentialAnimation {
              id: valPulse
              NumberAnimation { target: valText; property: "scale"; to: 0.9; duration: 60; easing.type: Easing.OutQuad }
              NumberAnimation { target: valText; property: "scale"; to: 1.0; duration: 120; easing.type: Easing.OutQuad }
          }
      }
    }
}
