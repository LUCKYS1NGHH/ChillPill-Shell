import Quickshell
import QtQuick

Text {

  property string fontFamily: Theme.fontFamily

  text: Qt.formatDateTime(clock.date, Config.clockFormat)
  color: Theme.fg

  font {
    family: Theme.fontFamily
    weight: 500
    pixelSize: 10
    letterSpacing: -0.5
  }
}
