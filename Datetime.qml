import Quickshell
import QtQuick

Text {

  property string fontFamily: "Monocraft"
  property string fg: "#cbcbcb"


  text: Qt.formatDateTime(clock.date, "hh:mm a ddd, dd MMM yyyy")
  color: fg

  font {
    family: Theme.fontFamily
    weight: 500
    pixelSize: 10
    letterSpacing: -0.5
  }
}
