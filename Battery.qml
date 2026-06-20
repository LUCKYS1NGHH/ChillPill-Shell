import Quickshell
import QtQuick
import Quickshell.Services.UPower

Text {
  id: batteryText
  property string fontFamily: "Monocraft"

  anchors {
    right: parent.right
    rightMargin: 85
    verticalCenter: parent.verticalCenter
  }

  text: {
    var val = UPower.displayDevice.percentage;
    // Only multiply if value is low (0-1 range) but non-zero
    if (val < 1.0 && val > 0) {
        val = val * 100;
    }
    Math.round(val) + "%"
  }

  color: "#dadada"

  font {
    family: fontFamily
    weight: 500
    pixelSize: 10
    letterSpacing: -0.5
  }
}
