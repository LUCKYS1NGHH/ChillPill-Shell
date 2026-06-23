import Quickshell
import QtQuick

Text {

  property string fontFamily: "Monocraft"

  text: Qt.formatDateTime(clock.date, "hh:mm")
  color: "#dadada"

  font {
    family: Theme.fontFamily
    weight: 500
    pixelSize: 10
    letterSpacing: -0.5
  }
}
