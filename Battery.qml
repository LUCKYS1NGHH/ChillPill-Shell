import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower

RowLayout {
  id: root
  spacing: 6

  property string fg: "#dadada"

  anchors {
    left: parent.left
    leftMargin: 20
    verticalCenter: parent.verticalCenter
  }

  property var battery: UPower.displayDevice
  property bool charging: battery.stats === UPowerDeviceState.Charging
  readonly property int level: Math.round(battery.percentage * 100)

  readonly property string icon:{
    if (charging) return String.fromCodePoint(0xf0084)
    if (level >= 100) return String.fromCodePoint(0xf0082)
    if (level < 10) return String.fromCodePoint(0xf007d)

    return String.fromCodePoint(0xf0081 + (Math.floor(level / 10) - 1))
  }

  Text {
    text: root.icon
    color: root.charging ? "#53ce62"
                         : root.level <= 15 ? "#ff2525"
                         : root.level <= 30 ? "#ceb353"
                         : "#53ce62"

    font {
      family: "JetBrainsMono Nerd Font"
      pixelSize: 10
    }
  }

  Text {
    text: root.level + "%"
    color: fg

    font {
      family: Theme.fontFamily
      weight: 500
      pixelSize: 10
    }
  }
}
