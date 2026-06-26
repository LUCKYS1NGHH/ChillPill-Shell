import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

RowLayout {

  anchors {
    centerIn: parent
  }

  Repeater {
    model: 5 // max workspace buttons/texts to show

    delegate: Rectangle {
      id: wsButton

      required property int index
      property var ws: Hyprland.workspaces.values.find(w => w.id === index + 1)
      property bool isActive: Hyprland.focusedWorkspace?.id === (index + 1)
      property string activeBg: "#4d5258"
      property string inactiveBg: "#393c41"

      width: 17.5
      height: width
      radius: 8
      color: isActive ? activeBg : (ws ? inactiveBg : "transparent")

      // animate color transition on workspace switch
      Behavior on color { ColorAnimation { duration: 120 } }

      Text {
        anchors.centerIn: parent
        text: wsButton.index + 1
        color: wsButton.isActive ? "#ffffff" : "#dae0ea"
        font {
          family: Theme.fontFamily
          pixelSize: 9
          weight: 300
        }
      }

      // clickable text buttons
      MouseArea {
        anchors.fill: parent
        onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + (wsButton.index + 1 + "})"))
      }
    }
  }
}
