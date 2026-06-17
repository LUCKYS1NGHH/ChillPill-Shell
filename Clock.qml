import Quickshell
import QtQuick

Text {
  anchors.right: parent.right
  text: Qt.formatDateTime(clock.date, "hh:mm A dd, yyyy")
  color: "#dadada"

  font {
    family: "Monocraft"
    weight: 500
    pixelSize: 10
    letterSpacing: -0.5
  }
}
