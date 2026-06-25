import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

ShellRoot {
  property string bg: Theme.bg
  property string fg: Theme.fg
  property string fontFamily: Theme.fontFamily
  property int avatarSize: 48
  property int buttonSize: 20
  property string buttonFg: "#353535"
  property int buttonctlRadius: 6

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

        RowLayout {
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

          // username
          Process {
            id: whoamiProc
            command: ["sh", "-c", 'whoami']
            running: true
            stdout: StdioCollector {
              onStreamFinished: whoamiText.text = this.text.trim()
            }
          }

          // uptime
          Process {
            id: uptimeProc
            command: ["sh", "-c", 'uptime -p']
            running: true
            stdout: StdioCollector {
              onStreamFinished: uptimeText.text = this.text
            }
          }

          // uptime refresh every 60 sec
          Timer {
            interval: 60000
            running: box.expanded
            repeat: true
            triggeredOnStart: true
            onTriggered: {
              uptimeProc.running = false
              uptimeProc.running = true
            }
          }

          // username + uptime stacked
          ColumnLayout {
            spacing: 2
            Layout.alignment: Qt.AlignVCenter

            Text {
              id: whoamiText
              color: Theme.fg
              Layout.leftMargin: 10
              font { family: Theme.fontFamily; pixelSize: 13; weight: 600 }
            }

            Text {
              id: uptimeText
              color: Theme.fg
              opacity: 0.6
              Layout.leftMargin: 10
              font { family: Theme.fontFamily; pixelSize: 8; weight: 400 }
            }
          }
        }

        Battery {
          fontSize: 14
          anchors.top: parent.top
          anchors.right: parent.right
          anchors.topMargin: 8
          anchors.rightMargin: 12
        }

        // rectangle where poweroff, sleep etc. buttons placed
        Rectangle {
          color: "#212121"
          implicitWidth: 15
          implicitHeight: 30
          radius: 8

          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.topMargin: 60


          RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 8

            // lock
            Rectangle {
              width: buttonSize; height: buttonSize
              radius: buttonctlRadius; color: buttonFg
              Layout.alignment: Qt.AlignVCenter
              Text { anchors.centerIn: parent; text: ""; color: Theme.fg; font.pixelSize: 8 }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { lockProc.running = false; lockProc.running = true }
              }
              Process { id: lockProc; command: ["bash", "-c", "hyprlock"]; running: false }
            }

            // sleep
            Rectangle {
              width: buttonSize; height: buttonSize
              radius: buttonctlRadius; color: buttonFg
              Layout.alignment: Qt.AlignVCenter
              Text { anchors.centerIn: parent; text: "󰤄"; color: Theme.fg; font.pixelSize: 9 }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { sleepProc.running = false; sleepProc.running = true }
              }
              Process { id: sleepProc; command: ["bash", "-c", "systemctl suspend"]; running: false }
            }

            Item { Layout.fillWidth: true }

            Datetime { id: datetimeItem; anchors.centerIn: parent; dateFg: "#aaaaaa"; }

            Item { Layout.fillWidth: true }

            // reboot
            Rectangle {
              width: buttonSize; height: buttonSize
              radius: buttonctlRadius; color: buttonFg
              Layout.alignment: Qt.AlignVCenter
              Text { anchors.centerIn: parent; text: ""; color: Theme.fg; font.pixelSize: 9; }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { rebootProc.running = false; rebootProc.running = true }
              }
              Process { id: rebootProc; command: ["bash", "-c", "systemctl reboot"]; running: false }
            }

            // shutdown
            Rectangle {
              width: buttonSize; height: buttonSize
              radius: buttonctlRadius; color: buttonFg
              Layout.alignment: Qt.AlignVCenter
              Text { anchors.centerIn: parent; text: "󰐥"; color: Theme.fg; font.pixelSize: 12; }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { shutdownProc.running = false; shutdownProc.running = true }
              }
              Process { id: shutdownProc; command: ["bash", "-c", "systemctl poweroff"]; running: false }
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
