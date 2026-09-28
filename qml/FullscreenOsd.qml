import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
  id: root

  default property alias content: cardRow.children
  property alias extra: extraHolder.data

  Item {
    id: extraHolder
    visible: false
  }

  property bool active: false
  property int cardWidth: 280
  property int cardHeight: 50
  property int cardRadius: 99
  property int restMargin: 1

  // in decelerates into place, out accelerates away and is quicker
  property int enterDuration: 300
  property int exitDuration: 200

  // 0 = parked above the top edge, 1 = resting in view
  property real slide: 0
  property real fade: 0
  // stays mapped through the exit, else the slide out is never seen
  property bool shown: false

  WlrLayershell.layer: WlrLayershell.Overlay
  exclusiveZone: 0
  color: "transparent"
  anchors { top: true; left: true; right: true }
  implicitHeight: cardBg.implicitHeight + 40

  visible: shown

  readonly property real parkedOffset: -(cardBg.implicitHeight + 60)
  margins.top: parkedOffset + (restMargin - parkedOffset) * slide

  onActiveChanged: active ? slideIn() : slideOut()

  function slideIn() {
    shown = true
    slideAnim.stop()
    fadeAnim.stop()
    // resumes from the current position, so an interrupted exit reverses
    slideAnim.easing.type = Easing.OutQuint
    fadeAnim.easing.type = Easing.OutCubic
    slideAnim.from = slide; slideAnim.to = 1; slideAnim.duration = enterDuration; slideAnim.start()
    fadeAnim.from = fade; fadeAnim.to = 1; fadeAnim.duration = enterDuration * 0.45; fadeAnim.start()
  }

  function slideOut() {
    if (!shown) return
    slideAnim.stop()
    fadeAnim.stop()
    slideAnim.easing.type = Easing.InCubic
    // fade trails the slide, else the card blinks out mid travel
    fadeAnim.easing.type = Easing.InOutQuad
    slideAnim.from = slide; slideAnim.to = 0; slideAnim.duration = exitDuration; slideAnim.start()
    fadeAnim.from = fade; fadeAnim.to = 0; fadeAnim.duration = exitDuration * 1.2; fadeAnim.start()
  }

  NumberAnimation {
    id: slideAnim
    target: root
    property: "slide"
    // card is off screen, safe to unmap
    onFinished: if (!root.active) root.shown = false
  }

  NumberAnimation {
    id: fadeAnim
    target: root
    property: "fade"
  }

  Rectangle {
    id: cardBg
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    color: Theme.bgD
    radius: root.cardRadius
    implicitWidth: root.cardWidth
    implicitHeight: root.cardHeight
    clip: true

    opacity: root.fade
    // follows the faster fade curve: full size while still travelling
    scale: 0.88 + 0.12 * root.fade
    transformOrigin: Item.Top

    RowLayout {
      id: cardRow
      anchors.centerIn: parent
      spacing: 10
    }
  }
}
