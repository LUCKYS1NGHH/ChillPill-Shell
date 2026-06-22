import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

RowLayout {
  spacing: 5

  Repeater {
    model: 5

    delegate: Rectangle {
      id: wsButton

      required property int index
      property var ws: Hyprland.workspaces.values.find(w => w.id === index + 1)
      property bool isActive: Hyprland.focusedWorkspace?.id === (index + 1)
      property string activeBg: "#4d5258"
      property string inactiveBg: "#393c41"

      implicitWidth: 17.5
      implicitHeight: implicitWidth
      radius: 8
      color: isActive ? activeBg : (ws ? inactiveBg : "transparent")

      Behavior on color {
        ColorAnimation { duration: 150 }
      }

      Text {
        anchors.centerIn: parent
        text: wsButton.index + 1
        color: wsButton.isActive ? "#ffffff" : "#dae0ea"
        font {
          family: Theme.fontFamily
          pixelSize: 9
          weight: Font.Medium
        }
      }

      MouseArea {
        anchors.fill: parent
        onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + (wsButton.index + 1 + "})"))
      }
    }
  }
}
