import Quickshell
import Quickshell.Wayland
import QtQuick

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
  property int animDuration: 260

  WlrLayershell.layer: WlrLayershell.Overlay
  exclusiveZone: 0
  color: "transparent"
  anchors { top: true; left: true; right: true }
  implicitHeight: cardBg.implicitHeight + 40

  property real slideOffset: active ? restMargin : -(cardBg.implicitHeight + 60)
  margins.top: slideOffset

  Behavior on slideOffset {
    NumberAnimation { duration: root.animDuration; easing.type: Easing.OutBack; easing.overshoot: 0.9 }
  }

  Rectangle {
    id: cardBg
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    color: Theme.bg
    radius: root.cardRadius
    implicitWidth: root.cardWidth
    implicitHeight: root.cardHeight

    opacity: root.active ? 1 : 0
    scale: root.active ? 1 : 0.85
    transformOrigin: Item.Top

    Behavior on opacity {
      NumberAnimation { duration: root.animDuration * 0.6; easing.type: Easing.OutExpo }
    }

    Row {
      id: cardRow
      anchors.centerIn: parent
      spacing: 10
    }
  }
}
