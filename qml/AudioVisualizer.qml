import QtQuick

//  AudioVisualizer.qml - spectrum bar renderer, shared by the control center's
//  media player and the pill bar's "audioVisualizer" module.
//
//  Two looks, picked with `centered`:
//    false - bars grow up from the bottom edge (media player, where the row
//            sits on the card's lower border)
//    true  - bars grow symmetrically out of the middle line, so the row reads
//            as a small wave (pill bar, where there's no card under it)
//
//  Both users only need to feed `values` (0-100 per bar, low → high frequency).
Item {
  id: root

  property int barCount: 16
  property real barWidth: 2.5
  property real barSpacing: 2
  property real maxBarHeight: 14
  property real minBarHeight: 3
  property real barRadius: 1.5
  property color barColor: Theme.accent
  // when set (not "transparent"), odd bars get this color instead of barColor
  property color barSecondaryColor: "transparent"
  // mirrored look: bars expand from the vertical center instead of the bottom
  property bool centered: false
  property real animationDuration: 70
  property var values: []

  implicitWidth: barCount * barWidth + (barCount - 1) * barSpacing
  implicitHeight: maxBarHeight

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
          anchors.horizontalCenter: parent.horizontalCenter
          // mirrored rows hug the middle line, plain ones the bottom edge;
          // the unused anchor is unset by binding it to undefined
          anchors.verticalCenter: root.centered ? parent.verticalCenter : undefined
          anchors.bottom: root.centered ? undefined : parent.bottom
          width: root.barWidth
          // in centered mode maxBarHeight is the full up+down extent of a bar
          height: barContainer.targetHeight
          radius: root.barRadius
          color: root.barSecondaryColor !== "transparent" ? (index % 2 === 0 ? root.barColor : root.barSecondaryColor) : root.barColor

          Behavior on height {
            NumberAnimation {
                duration: root.animationDuration
                easing.type: Easing.OutQuad
            }
          }
        }
      }
    }
  }
}
