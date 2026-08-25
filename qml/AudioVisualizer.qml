import QtQuick
import QtQuick.Layouts

Item {
  id: root

  property int barCount: 16
  property real barWidth: 2.5
  property real barSpacing: 2
  property real maxBarHeight: 14
  property real minBarHeight: 3
  property real barRadius: 1.5
  property color barColor: Theme.accent
  property color barSecondaryColor: "transparent"
  property var values: []

  implicitWidth: barCount * barWidth + (barCount - 1) * barSpacing
  implicitHeight: maxBarHeight
  width: implicitWidth
  height: implicitHeight

  Row {
    anchors.fill: parent
    spacing: root.barSpacing

    Repeater {
      model: root.barCount
      delegate: Item {
        id: barContainer
        width: root.barWidth
        height: root.height

        readonly property real targetHeight: Math.max(root.minBarHeight, (rawVal / 100) * root.maxBarHeight)
        readonly property real rawVal: (root.values && index < root.values.length) ? (root.values[index] || 0) : 0

        Rectangle {
          anchors.bottom: parent.bottom
          anchors.horizontalCenter: parent.horizontalCenter
          width: root.barWidth
          height: barContainer.targetHeight
          radius: root.barRadius
          color: root.barSecondaryColor !== "transparent" ? (index % 2 === 0 ? root.barColor : root.barSecondaryColor) : root.barColor

          Behavior on height {
            NumberAnimation {
                duration: 70
                easing.type: Easing.OutQuad
            }
          }
        }
      }
    }
  }
}
