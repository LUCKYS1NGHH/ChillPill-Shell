import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

ShellRoot {
  property string bg: Theme.bg
  property string fg: Theme.fg
  property string fontFamily: Theme.fontFamily

  PanelWindow {

    implicitHeight: box.implicitHeight + margins.top

    anchors {
      top: true
      left: true
      right: true
    }
    margins {
      top: 5
    }
    exclusiveZone: 28 // fixed strut, never changes
    color: "transparent"

    // Mask input to only the capsule
    mask: Region {
      Region {
        intersection: Intersection.Combine
        x: Math.floor(box.x)
        y: Math.floor(box.y)
        width: Math.ceil(box.width)
        height: Math.ceil(box.height)
      }
    }

    Rectangle {
      id: box
      anchors.centerIn: parent

      property bool hovered: false
      property bool expanded: false

      implicitWidth: expanded ? 420 : row.implicitWidth + (hovered ? 68 : 56)
      implicitHeight: expanded ? 420 : row.implicitHeight + (hovered ? 10 : 10)

      radius: 20
      color: bg

      Behavior on implicitWidth {
        NumberAnimation { duration: 220; easing.type: Easing.OutExpo }
      }
      Behavior on implicitHeight {
        NumberAnimation { duration: 450; easing.type: Easing.OutExpo }
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: box.hovered = true
        onExited: box.hovered = false
        onClicked: box.expanded = !box.expanded
      }

      RowLayout {
        id: row
        spacing: 15
        anchors.centerIn: parent
        anchors.leftMargin: 28
        anchors.rightMargin: 28
        opacity: box.expanded ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 150 } }

        Battery {}
        Volume {}
        Workspaces {}
        Network {}
        Clock {}
      }

      // placeholder for expanded control center content
      Item {
        anchors.fill: parent
        anchors.margins: 16
        opacity: box.expanded ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
        visible: opacity > 0

        // Widgets addition later to add from here
      }

      SystemClock {
        id: clock
        precision: SystemClock.Minutes
      }
    }
  }
}
