import Quickshell
import QtQuick
import QtQuick.Layouts

RowLayout {
  id: root

  property string fg: "#dadada"
  property int fontSize: 10 * Config.pillScale
  property var battery: box.battery
  property bool charging: box.charging

  spacing: 4 * Config.paddingScale

  // icon
  Text {
    text: box.batteryIcon
    color: box.batteryIconColor

    font {
      family: Theme.nerdFontFamily
      pixelSize: fontSize
    }
  }

  // percentage
  Text {
    text: box.batteryLevel + "%"
    color: fg

    font {
      family: Theme.fontFamily
      weight: 500
      pixelSize: fontSize
    }
  }
}
