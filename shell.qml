import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

ShellRoot {

  property string bg: Theme.bg
  property string fg: Theme.fg
  property string fontFamily: Theme.fontFamily

  PanelWindow {
    implicitWidth: box.implicitWidth + 90
    implicitHeight: box.height

    anchors {
      top: true
    }

    margins {
      top: 9 // margin top for the bar
    }

    exclusionMode: ExclusionMode.High
    color: "transparent"

    Rectangle {
      id: box
      height: 30
      implicitWidth: row.implicitWidth + (hovered ? 70 : 56)
      anchors.centerIn: parent
      radius: 99

      color: bg
      property bool hovered: false

      Behavior on implicitWidth {
        NumberAnimation {
          duration: 200
          easing.type: Easing.OutExpo
        }
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: box.hovered = true
        onExited: box.hovered = false
      }

      RowLayout {
        id: row
        spacing: 18
        anchors.fill: parent
        anchors.leftMargin: 28
        anchors.rightMargin: 28

        Battery {}
        Volume {}
        Workspaces {}
        Network {}
        Clock {}
      }

      SystemClock {
        id: clock
        precision: SystemClock.Minutes
      }
    }
  }
}
