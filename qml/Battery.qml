import Quickshell
import QtQuick
import QtQuick.Layouts
RowLayout {
  id: root
  property string fg: "#dadada"
  property int fontSize: 10 * Config.pillScale
  property var battery: box.battery
  property bool charging: box.charging
  property bool hasBattery: box.hasBattery
  spacing: 4 * Config.paddingScale

  // icon: battery on laptops, plug on desktops
  Text {
    text: box.batteryIcon
    color: hasBattery ? box.batteryIconColor : "#4bd25c"

    font {
      family: Theme.nerdFontFamily
      pixelSize: hasBattery ? fontSize : fontSize + 2
    }
  }

  // percentage, only makes sense with a battery like laptop
  Text {
    visible: hasBattery
    text: box.batteryLevel + "%"
    color: fg

    font {
      family: Theme.fontFamily
      weight: 500
      pixelSize: fontSize
    }
  }
}
