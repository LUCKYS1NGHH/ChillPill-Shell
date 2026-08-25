import Quickshell
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts

RowLayout {
  id: root

  spacing: 4 * Config.paddingScale

  property string iconFg: "#6791dc"
  property string disconIconFg: "#9ea9bd"

  property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi)
  property var active: wifiDevice ? wifiDevice.networks.values.find(n => n.connected) : null

  property var tetherDevice: Networking.devices.values.find(d => d.type === DeviceType.Wired && d.connected)
  readonly property bool tethered: tetherDevice !== undefined

  readonly property real signal: active ? active.signalStrength : 0

  readonly property string icon: {
    if (root.tethered) return String.fromCodePoint(0xf287) // nf-fa-usb
    if (!Networking.wifiEnabled) return String.fromCodePoint(0xf092d)
    if (!active) return String.fromCodePoint(0xf092d)
    let s = signal / 100
    let tier = s >= 0.75 ? 4
             : s >= 0.50 ? 3
             : s >= 0.25 ? 2
             : 1
    return String.fromCodePoint(0xf091f + (tier + 1) * 3)
  }

  Text {
    text: root.icon
    color: root.tethered ? root.iconFg : (Networking.wifiEnabled ? iconFg : disconIconFg)

    font {
      family: "FiraCode Nerd Font Propo"
      pixelSize: 10 * Config.pillScale
    }
  }

  Text {
      text: {
          if (root.tethered) return "USB"
          if (!Networking.wifiEnabled) return "off"
          if (!root.active) return "N/A"
          return root.active.name
      }
      color: Theme.fg
      font { family: Theme.fontFamily; pixelSize: 10 * Config.pillScale; weight: 500 }
      elide: Text.ElideRight
      Layout.maximumWidth: 90 * Config.pillScale
  }
}
