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
    var base = ""
    if (level >= 95) base = String.fromCodePoint(0xf0079) 
    else if (level >= 70) base = String.fromCodePoint(0xf0082)
    else if (level >= 40) base = String.fromCodePoint(0xf007e)
    else if (level >= 35) base = String.fromCodePoint(0xf007c)
    else if (level >= 10) base = String.fromCodePoint(0xf007a)
    else base = String.fromCodePoint(0xf0083)

    if (charging) base += String.fromCodePoint(0xf140b)
    return base
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
