import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower

RowLayout {
  id: root

  property string fg: "#dadada"
  property int fontSize: 10

  property var battery: UPower.displayDevice
  property bool charging: battery.state === UPowerDeviceState.Charging
  readonly property int level: Math.round(battery.percentage * 100)

  readonly property string icon: {
    const icons = [0xf0083, 0xf007a, 0xf007d, 0xf007c, 0xf007d, 0xf007e, 0xf007f, 0xf0082, 0xf0081, 0xf0079]
    const base = String.fromCodePoint(icons[Math.min(Math.floor(level / 10), 9)])
    return charging ? base + String.fromCodePoint(0xf140b) : base
  }

  Text {
    text: root.icon
    color: root.charging ? "#4bd25c"
                         : root.level <= 15 ? "#e22323"
                         : root.level <= 30 ? "#eecc47"
                         : "#4bd25c"

    font {
      family: "JetBrainsMono Nerd Font"
      pixelSize: fontSize
    }
  }

  Text {
    text: root.level + "%"
    color: fg

    font {
      family: Theme.fontFamily
      weight: 500
      pixelSize: fontSize
    }
  }
}
