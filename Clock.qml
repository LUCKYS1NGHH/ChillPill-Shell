import Quickshell
import QtQuick

Text {
  anchors {
    right: parent.right
    rightMargin: 20
    verticalCenter: parent.verticalCenter
  }
  text: Qt.formatDateTime(clock.date, "hh:mm")
  color: "#dadada"


  font {
    family: "Monocraft"
    weight: 500
    pixelSize: 10
    letterSpacing: -0.5
  }
}
