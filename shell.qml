import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

ShellRoot {
  property string bg: Theme.bg
  property string fg: Theme.fg
  property string fontFamily: Theme.fontFamily
  property int avatarSize: 48

  PanelWindow {

    implicitHeight: box.implicitHeight + margins.top

    anchors {
      top: true
      left: true
      right: true
    }
    margins {
      top: 9
    }
    exclusiveZone: 26 // fixed strut, never changes
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
      //anchors.centerIn: parent
      anchors.top: parent.top
      anchors.horizontalCenter: parent.horizontalCenter
      property bool hovered: false
      property bool expanded: false

      implicitWidth: expanded ? 420 : row.implicitWidth + (hovered ? 68 : 56)
      implicitHeight: expanded ? 420 : row.implicitHeight + (hovered ? 10 : 10)

      radius: 20
      color: bg

      Behavior on implicitWidth {
        NumberAnimation { duration: 225; easing.type: Easing.OutExpo }
      }
      Behavior on implicitHeight {
        NumberAnimation { duration: 550; easing.type: Easing.OutExpo }
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
        anchors.centerIn: parent
        width: box.implicitWidth - 30
        height: box.expanded ? box.implicitHeight - 30 : 0  // don't fight the animation
        opacity: box.expanded ? 1 : 0
        Behavior on opacity {
          SequentialAnimation {
            PauseAnimation { duration: box.expanded ? 20 : 0 }
            NumberAnimation { duration: 100; easing.type: Easing.OutExpo }
          }
        }
        visible: opacity > 0

        // profile picture
        Item {
          anchors.top: parent.top
          anchors.left: parent.left
          width: avatarSize
          height: avatarSize

          Image {
            id: avatarImg
            anchors.fill: parent
            source: "file:///home/xingyun/.pfp.png"
            fillMode: Image.PreserveAspectCrop
            asynchronous: false
            visible: false
          }

          OpacityMask {
            anchors.fill: parent
            source: avatarImg
            maskSource: Rectangle {
              width: avatarSize
              height: avatarSize
              radius: avatarSize / 2
            }
          }
        }
      }
      SystemClock {
        id: clock
        precision: SystemClock.Minutes
      }
    }
  }
}
