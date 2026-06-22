import QtQuick
import Quickshell
import Quickshell.Io

Item {

  anchors {
    left: parent.left
    leftMargin: 20
    verticalCenter: parent.verticalCenter
  }

  implicitWidth: weatherText.implicitWidth
  implicitHeight: weatherText.implicitHeight

  Process {
    id: wttrProc
    command: ["sh", "-c", 'python3 ~/.config/hypr/scripts/hyprlock-wttr.py']
    running: true
    stdout: StdioCollector {
      onStreamFinished: weatherText.text = this.text
    }
  }

  Text {
    id: weatherText
    color: Theme.fg

    font {
      family: Theme.fontFamily
      weight: 500
      pixelSize: 10
      letterSpacing: -0.3
    }
  }
}
