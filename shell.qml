import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

ShellRoot {

  property string bg: Theme.bg
  property string fg: Theme.fg
  property string fontFamily: Theme.fontFamily

  PanelWindow {
    implicitWidth: 700
    implicitHeight: box.height

    anchors {
      top: true
    }

    margins {
      top: 8 // margin top for the bar
    }

    exclusionMode: ExclusionMode.High
    color: "transparent"

    Rectangle {
      id: box
      width: hovered ? 508 : 500
      height: 30
      implicitWidth: row.implicitWidth + 24
      anchors.centerIn: parent
      radius: 99
      color: bg
      property bool hovered: false

      Behavior on width {
        NumberAnimation {
          duration: 270
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
        spacing: 7
        anchors.centerIn: parent
        id: row

        Workspaces {} // import workspace buttons code from other file

        Item { Layout.fillWidth: true }
      }

      Clock {} // same method to import clock

      SystemClock {
        id: clock
        precision: SystemClock.Minutes
      }
    }
  }
}
