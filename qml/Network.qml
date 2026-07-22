import Quickshell
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts

RowLayout {
  id: root

  property string iconFg: "#6791dc"
  property string disconIconFg: "#9ea9bd"

  property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi)
  property var active: wifiDevice ? wifiDevice.networks.values.find(n => n.connected) : null

  readonly property real signal: active ? active.signalStrength : 0

  readonly property string icon: {
    if (!Networking.wifiEnabled) return String.fromCodePoint(0xf092d)
    if (!active) return String.fromCodePoint(0xf092d)

    let tier = signal >= 0.75 ? 4
             : signal >= 0.50 ? 3
             : signal >= 0.25 ? 2
             : 1

      return String.fromCodePoint(0xf091f + (tier + 1) * 3)
  }

  Text {
    text: root.icon
    color: Networking.wifiEnabled ? iconFg : disconIconFg

    font {
      family: "FiraCode Nerd Font Propo"
      pixelSize: 10
    }
  }

  Text {
      text: {
          if (!Networking.wifiEnabled) return "off"
          if (!root.active) return "N/A"
          return root.active.name
      }
      color: Theme.fg
      font { family: Theme.fontFamily; pixelSize: 10; weight: 500 }
      elide: Text.ElideRight
      Layout.maximumWidth: 90
  }
}
