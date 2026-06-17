import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

ShellRoot {
  PanelWindow {
    anchors {
      top: true
      left: true
      right: true
    }
    implicitHeight: 32
    color: "#1d1d1d"

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 15
      anchors.rightMargin: 15

      RowLayout {
        spacing: 7

        Repeater {
          model: 5 // max available workspaces to show in bar

          Text {
            property bool isActive: Hyprland.focusedWorkspace?.id === (index + 1)
            text: index + 1
            color: isActive ? "#fbfbfb" : "#5d5d5d"

            font {
              family: "Monocraft"
              weight: 500
              pixelSize: 10
              letterSpacing: -1.5
            }
          }
        }
      }

      Clock {} // import clock from the other code
    }

    SystemClock {
      id: clock
      precision: SystemClock.Minutes
    }
  }
}
