import QtQuick
import QtQuick.Layouts
import IslandBackend

RowLayout {
  id: root

  readonly property real dpi: Config.dpiScale

  property real buttonBorderWidth
  property string buttonBorderColor
  property real buttonWidth
  property real buttonHeight
  property real buttonRadius
  property color buttonBgOff
  property color buttonFgOff

  property bool notificationPopup: false
  property bool controlCenterOpen: false
  property bool mediaAutoOpened: false
  property bool wifiPanelOpened: false
  property bool btPanelOpened: false
  property bool hasPlayer: false
  property real playerHeight: 0

  anchors.top: parent.top
  anchors.topMargin: hasPlayer ? playerHeight + 92 : 5
  anchors.left: parent.left
  anchors.right: parent.right
  anchors.leftMargin: 3 * dpi
  anchors.rightMargin: 5 * dpi

  onControlCenterOpenChanged: {
    if (!controlCenterOpen) root.wifiPanelOpened = false; root.btPanelOpened = false
  }

  // wifi
  Rectangle {
    id: wifiBtn
    implicitWidth: root.buttonWidth
    implicitHeight: root.buttonHeight
    radius: root.buttonRadius
    visible: root.controlCenterOpen && !root.mediaAutoOpened
    color: WifiController.enabled
            ? (wifiHover.hovered ? Qt.lighter("#212529", 1.2) : "#212529")
            : (wifiHover.hovered ? Qt.lighter(root.buttonBgOff, 1.3) : root.buttonBgOff)
    border.width: WifiController.enabled ? 0 : buttonBorderWidth
    border.color: buttonBorderColor
    scale: wifiMouse.pressed ? 0.93 : 1.0
    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }

    RowLayout {
      anchors.centerIn: parent
      spacing: 5 * root.dpi
      Text {
        text: "\uf1eb" // wifi glyph
        color: WifiController.enabled ? "#4282e9" : root.buttonFgOff
        font { family: Theme.nerdFontFamily; pixelSize: 12 }
      }
      Text {
        text: !WifiController.enabled ? "Off"
            : WifiController.currentSsid.length > 0 ? WifiController.currentSsid
            : (WifiController.statusText.length > 0 ? WifiController.statusText : "Not connected")
        color: WifiController.enabled ? "#dedede" : root.buttonFgOff
        font { family: Theme.fontFamily; pixelSize: 10; weight: 400 }
        elide: Text.ElideRight
        Layout.maximumWidth: 50
      }
    }

    HoverHandler { id: wifiHover }
    MouseArea {
      id: wifiMouse
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: Qt.PointingHandCursor
      onClicked: (mouse) => {
        if (mouse.button === Qt.RightButton) {
          root.wifiPanelOpened = !root.wifiPanelOpened
          if (root.wifiPanelOpened && WifiController.enabled) WifiController.refreshNetworks(true)
          return
        }
        WifiController.setEnabled(!WifiController.enabled)
      }
    }
  }

  WifiPanel {
    visible: root.wifiPanelOpened
    anchorX: root.mapToGlobal(root.width, 0).x - (600 * root.dpi) - (30 * root.dpi)
    anchorY: wifiBtn.mapToGlobal(0, 0).y
  }

  onNotificationPopupChanged: {
    if (root.notificationPopup) root.wifiPanelOpened = false; root.btPanelOpened = false
  }

  // silent notifications
  Rectangle {
    id: dndBtn
    implicitWidth: root.buttonWidth
    implicitHeight: root.buttonHeight
    radius: root.buttonRadius
    visible: root.controlCenterOpen && !root.mediaAutoOpened
    color: notificationModule.dndEnabled
    ? (dndHover.hovered ? Qt.lighter("#262626", 1.2) : "#262626")
    : (dndHover.hovered ? Qt.lighter(root.buttonBgOff, 1.3) : root.buttonBgOff)
    border.width: notificationModule.dndEnabled ? 0 : buttonBorderWidth
    border.color: buttonBorderColor
    scale: dndMouse.pressed ? 0.93 : 1.0
    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }

    Text {
      text: String.fromCodePoint(0xf1f6)
      color: notificationModule.dndEnabled ? "#fff9eb" : root.buttonFgOff
      anchors.centerIn: parent
      font { family: Theme.nerdFontFamily; pixelSize: 13 }
    }
    HoverHandler { id: dndHover }
    MouseArea {
      id: dndMouse
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: notificationModule.dndEnabled = !notificationModule.dndEnabled
    }
  }

  // timer / countdown
  Rectangle {
    id: timerBtn
    implicitWidth: root.buttonWidth
    implicitHeight: root.buttonHeight
    radius: root.buttonRadius
    color: countdownModule.running
           ? (timerHover.hovered ? Qt.lighter("#212529", 1.2) : "#212529")
           : (timerHover.hovered ? Qt.lighter(root.buttonBgOff, 1.3) : root.buttonBgOff)
    border.width: countdownModule.running ? 0 : buttonBorderWidth
    border.color: buttonBorderColor
    scale: timerMouse.pressed ? 0.93 : 1.0
    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
    property int selectedMinutes: 1

    RowLayout {
      anchors.centerIn: parent
      spacing: 5 * root.dpi
      Text {
        text: {
          if (countdownModule.running) return String.fromCodePoint(0xf1ade)
          if (countdownModule.remainingSeconds > 0) return String.fromCodePoint(0xf1ae0)
          return String.fromCodePoint(0xf13ab)
        }
        color: countdownModule.running ? "#4490ee" : root.buttonFgOff
        font { family: Theme.nerdFontFamily; pixelSize: 14 }
      }
      Text {
        text: countdownModule.running || countdownModule.remainingSeconds > 0
            ? countdownModule.formatted() : timerBtn.selectedMinutes + "m"
        color: countdownModule.running ? "#dedede" : root.buttonFgOff
        font { family: Theme.fontFamily; pixelSize: 10; weight: 400 }
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
          const presets = Config.timerPresets
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

  // bluetooth
  Rectangle {
    id: btBtn
    implicitWidth: root.buttonWidth
    implicitHeight: root.buttonHeight
    radius: root.buttonRadius
    visible: root.controlCenterOpen && !root.mediaAutoOpened
    color: BluetoothController.enabled
            ? (btHover.hovered ? Qt.lighter("#212529", 1.2) : "#212529")
            : (btHover.hovered ? Qt.lighter(root.buttonBgOff, 1.3) : root.buttonBgOff)
    border.width: BluetoothController.enabled ? 0 : buttonBorderWidth
    border.color: buttonBorderColor
    scale: btMouse.pressed ? 0.93 : 1.0
    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
    RowLayout {
      anchors.centerIn: parent
      spacing: 5 * root.dpi

      Text {
        text: "\uf294"
        color: BluetoothController.enabled ? "#4282e9" : root.buttonFgOff
        font { family: Theme.nerdFontFamily; pixelSize: 15 }
      }
      Text {
        text: !BluetoothController.enabled ? "Off"
            : BluetoothController.currentDeviceName.length > 0 ? BluetoothController.currentDeviceName
            : (BluetoothController.statusText.length > 0 ? BluetoothController.statusText : "Not connected")
        color: BluetoothController.enabled ? "#dedede" : root.buttonFgOff
        font { family: Theme.fontFamily; pixelSize: 10; weight: 400 }
        elide: Text.ElideRight
        Layout.maximumWidth: 50
      }
    }
    HoverHandler { id: btHover }
    MouseArea {
      id: btMouse
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: Qt.PointingHandCursor
      onClicked: (mouse) => {
        if (mouse.button === Qt.RightButton) {
          root.btPanelOpened = !root.btPanelOpened
          if (root.btPanelOpened && BluetoothController.enabled) BluetoothController.refreshDevices(true)
          return
        }
        BluetoothController.setEnabled(!BluetoothController.enabled)
      }
    }
  }

  BluetoothPanel {
    visible: root.btPanelOpened
    anchorX: root.mapToGlobal(root.width, 0).x + (29 * root.dpi)
    anchorY: btBtn.mapToGlobal(0, 0).y
  }
}
