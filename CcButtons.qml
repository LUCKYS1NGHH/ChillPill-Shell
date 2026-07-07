import QtQuick
import QtQuick.Layouts

RowLayout {
  id: root

  property real buttonWidth
  property real buttonHeight
  property real buttonRadius
  property color buttonBgOff
  property color buttonFgOff

  property bool controlCenterOpen: false
  property bool mediaAutoOpened: false
  property bool hasPlayer: false
  property real playerHeight: 0

  anchors.top: parent.top
  anchors.topMargin: hasPlayer ? playerHeight + 92 : 5
  anchors.left: parent.left
  anchors.right: parent.right
  anchors.leftMargin: 5
  anchors.rightMargin: 5

  // silent notifications
  Rectangle {
    id: dndBtn
    width: root.buttonWidth
    height: root.buttonHeight
    radius: root.buttonRadius
    visible: root.controlCenterOpen && !root.mediaAutoOpened
    color: notificationModule.dndEnabled ? "#2e2c28" : (dndHover.hovered ? Qt.lighter(root.buttonBgOff, 1.3) : root.buttonBgOff)
    scale: dndMouse.pressed ? 0.93 : 1.0
    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }

    Text {
      text: String.fromCodePoint(0xf1f6)
      color: notificationModule.dndEnabled ? "#fbf5e8" : root.buttonFgOff
      anchors.centerIn: parent
      font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
    }
    HoverHandler { id: dndHover }
    MouseArea {
      id: dndMouse
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: notificationModule.dndEnabled = !notificationModule.dndEnabled
    }
  }

  Item { Layout.fillWidth: true }

  // timer / countdown
  Rectangle {
    id: timerBtn
    width: root.buttonWidth
    height: root.buttonHeight
    radius: root.buttonRadius
    color: countdownModule.running ? "#25282c" : (timerHover.hovered ? Qt.lighter(root.buttonBgOff, 1.3) : root.buttonBgOff)
    scale: timerMouse.pressed ? 0.93 : 1.0
    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
    property int selectedMinutes: 1

    RowLayout {
      anchors.centerIn: parent
      spacing: 5
      Text {
        text: {
          if (countdownModule.running) return String.fromCodePoint(0xf1ade)
          if (countdownModule.remainingSeconds > 0) return String.fromCodePoint(0xf1ae0)
          return String.fromCodePoint(0xf13ab)
        }
        color: countdownModule.running ? "#3978c7" : root.buttonFgOff
        font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
      }
      Text {
        text: countdownModule.running || countdownModule.remainingSeconds > 0
            ? countdownModule.formatted() : timerBtn.selectedMinutes + "m"
        color: countdownModule.running ? "#dedede" : root.buttonFgOff
        font { family: Theme.fontFamily; pixelSize: 12; weight: 400 }
      }
    }

    HoverHandler { id: timerHover }
    MouseArea {
      id: timerMouse
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      cursorShape: Qt.PointingHandCursor
      onClicked: (mouse) => {
        if (mouse.button === Qt.MiddleButton) { countdownModule.reset(); return }
        if (mouse.button === Qt.RightButton) {
          if (countdownModule.running || countdownModule.remainingSeconds > 0) return
          const presets = [5, 10, 15, 20, 25, 30]
          const idx = presets.indexOf(timerBtn.selectedMinutes)
          timerBtn.selectedMinutes = presets[(idx + 1) % presets.length]
          return
        }
        if (countdownModule.running) { countdownModule.pause(); return }
        if (countdownModule.remainingSeconds > 0) { countdownModule.resume(); return }
        countdownModule.start(timerBtn.selectedMinutes)
      }
    }
  }

}
