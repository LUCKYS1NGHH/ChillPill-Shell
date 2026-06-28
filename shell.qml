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
  property string buttonBg: "#353535"
  property string buttonHoverBg: "#bababa"
  property int buttonHoverSpeed: 120
  property int buttonctlRadius: 6

  // osd ui
  property int osdInWidth: 120
  property real osdInHeight: 3.7
  property int osdBarRadius: 2
  property int osdSpeed: 60

  PanelWindow {

    implicitHeight: 325

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
        x: Math.floor(box.x); y: Math.floor(box.y)
        width: Math.ceil(box.width); height: Math.ceil(box.height)
      }
      Region {
        intersection: Intersection.Combine
        x: Math.floor(calendarPopup.x); y: Math.floor(calendarPopup.y)
        width: calendarPopup.shown ? Math.ceil(calendarPopup.width) : 0
        height: calendarPopup.shown ? Math.ceil(calendarPopup.height) : 0
      }
    }

    // main box
    Rectangle {
      id: box
      anchors.top: parent.top
      anchors.horizontalCenter: parent.horizontalCenter

      property bool hovered: false
      property bool miniDashboard: false
      property bool volumeActive: false
      property bool brightnessActive: false
      property bool controlCenter: false

      Timer {
        id: volumeHideTimer
        interval: 850
        onTriggered: box.volumeActive = false
      }

      Timer {
          id: brightnessHideTimer
          interval: 850
          onTriggered: box.brightnessActive = false
      }

      implicitWidth: controlCenter ? 400 : miniDashboard ? 420 : volumeActive ? 220 : brightnessActive ? 220 : row.implicitWidth + (hovered ? 68 : 56)
      implicitHeight: controlCenter ? 200 : miniDashboard ? 120 : volumeActive ? 40 : brightnessActive ? 40 : row.implicitHeight + (hovered ? 10 : 10)

      radius: 20
      color: bg

      onMiniDashboardChanged: {
        if (!miniDashboard) calendarPopup.shown = false
      }

      Behavior on implicitWidth { NumberAnimation { duration: 225; easing.type: Easing.OutExpo } }
      Behavior on implicitHeight { NumberAnimation { duration: 550; easing.type: Easing.OutExpo } }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true

        acceptedButtons: Qt.LeftButton | Qt.RightButton 

        onEntered: box.hovered = true
        onExited: box.hovered = false

        onClicked: (mouse) => {
          if (mouse.button === Qt.LeftButton) {
            console.log("Left click detected, opening control center")
            box.controlCenter = !box.controlCenter
          }

          if (mouse.button === Qt.RightButton) {
              console.log("Right click detected, opening mini dashboard")
              box.miniDashboard = !box.miniDashboard
          }
        }
      }

      Brightness {
          id: brightnessModule
          visible: false
          onBrightnessUpdated: {
              box.brightnessActive = true
              brightnessHideTimer.restart()
          }
      }

      // modulues in bar
      RowLayout {
        id: row
        anchors.centerIn: parent
        anchors.leftMargin: 28
        anchors.rightMargin: 28
        spacing: 13
        opacity: box.controlCenter ? 0 : box.miniDashboard ? 0 : box.volumeActive ? 0 : box.brightnessActive ? 0 : 1

        Behavior on opacity { NumberAnimation { duration: 100 } }

        Battery {}
        Volume {
          id: volumeModule
          onVolumeChanged: {
            box.volumeActive = true
            volumeHideTimer.restart()
            }
        }
        Workspaces {}
        Network {}
        Clock {}
      }

      // volume OSD
      Item {
        anchors.centerIn: parent
        opacity: box.volumeActive ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        RowLayout {
          anchors.centerIn: parent
          spacing: 10

          Text {
            text: volumeModule.icon
            color: volumeModule.muted ? volumeModule.mutedFg : Theme.fg
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 15 }
          }

          Rectangle {
            width: osdInWidth; height: osdInHeight
            radius: osdBarRadius
            color: "#333"

            Rectangle {
              width: parent.width * (volumeModule.vol / 100)
              height: parent.height
              radius: 2
              color: Theme.fg
              Behavior on width { NumberAnimation { duration: osdSpeed } }
            }
          }

          Text {
            text: volumeModule.muted ? "muted" : volumeModule.vol + "%"
            color: volumeModule.muted ? volumeModule.mutedFg : Theme.fg
            font { family: Theme.fontFamily; pixelSize: 10; weight: 600 }
          }
        }
      }

      // brightness OSD
      Item {
          anchors.centerIn: parent
          opacity: box.brightnessActive && !box.volumeActive ? 1 : 0
          visible: opacity > 0
          Behavior on opacity { NumberAnimation { duration: 150 } }

          RowLayout {
              anchors.centerIn: parent
              spacing: 10

              Text {
                  text: brightnessModule.icon
                  color: Theme.fg
                  font { family: "JetBrainsMono Nerd Font"; pixelSize: 15 }
              }

              Rectangle {
                  width: osdInWidth; height: osdInHeight
                  radius: osdBarRadius
                  color: "#333"

                  Rectangle {
                      width: parent.width * brightnessModule.percent
                      height: parent.height
                      radius: 2
                      color: Theme.fg
                      Behavior on width { NumberAnimation { duration: osdSpeed } }
                  }
              }

              Text {
                  text: Math.round(brightnessModule.percent * 100) + "%"
                  color: Theme.fg
                  font { family: Theme.fontFamily; pixelSize: 10; weight: 600 }
              }
          }
      }

      // mini dashboard opens on right click
      Item {
        anchors.centerIn: parent
        width: box.implicitWidth - 30
        height: box.miniDashboard ? box.implicitHeight - 30 : 0  // don't fight the animation
        opacity: box.miniDashboard ? 1 : 0

        Behavior on opacity {
          SequentialAnimation {
            PauseAnimation { duration: box.miniDashboard ? 1 : 0 }
            NumberAnimation { duration: 300; easing.type: Easing.OutExpo }
          }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton)
                    box.miniDashboard = !box.miniDashboard
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
              onStreamFinished: { whoamiText.text = this.text.trim(); whoamiProc.running = false }
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
            running: box.miniDashboard
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

        // show battery in mini dashboard too
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
              radius: buttonctlRadius; color: buttonBg
              Layout.alignment: Qt.AlignVCenter
              Text {
                anchors.centerIn: parent;
                text: "";
                color: lockHover.containsMouse ? buttonHoverBg : Theme.fg;
                font.pixelSize: 8
                Behavior on color { ColorAnimation { duration: buttonHoverSpeed } }
              }

              MouseArea {
                id: lockHover
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { lockProc.running = false; lockProc.running = true }
                hoverEnabled: true
              }

              Process { id: lockProc; command: ["bash", "-c", "hyprlock"]; running: false }
            }

            // sleep
            Rectangle {
              width: buttonSize; height: buttonSize
              radius: buttonctlRadius; color: buttonBg
              Layout.alignment: Qt.AlignVCenter
              Text {
                anchors.centerIn: parent;
                text: "󰤄";
                color: sleepHover.containsMouse ? buttonHoverBg : Theme.fg;
                font.pixelSize: 9
                Behavior on color { ColorAnimation { duration: buttonHoverSpeed } }
              }

              MouseArea {
                id: sleepHover
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { sleepProc.running = false; sleepProc.running = true }
                hoverEnabled: true
              }
              Process { id: sleepProc; command: ["bash", "-c", "systemctl suspend"]; running: false }
            }

            Item { Layout.fillWidth: true }

            Datetime { id: datetimeItem; anchors.centerIn: parent; dateFg: "#aaaaaa"; }

            Item { Layout.fillWidth: true }

            // reboot
            Rectangle {
              width: buttonSize; height: buttonSize
              radius: buttonctlRadius; color: buttonBg
              Layout.alignment: Qt.AlignVCenter
              Text {
                anchors.centerIn: parent;
                text: "";
                color: rebootHover.containsMouse ? buttonHoverBg : Theme.fg;
                font.pixelSize: 9;
                Behavior on color { ColorAnimation { duration: buttonHoverSpeed } }
              }

              MouseArea {
                id: rebootHover
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { rebootProc.running = false; rebootProc.running = true }
                hoverEnabled: true
              }
              Process { id: rebootProc; command: ["bash", "-c", "systemctl reboot"]; running: false }
            }

            // shutdown
            Rectangle {
              width: buttonSize; height: buttonSize
              radius: buttonctlRadius; color: buttonBg
              Layout.alignment: Qt.AlignVCenter
              Text {
                anchors.centerIn: parent;
                text: "󰐥";
                color: shutdownHover.containsMouse ? buttonHoverBg : Theme.fg;
                font.pixelSize: 12;
                Behavior on color { ColorAnimation { duration: buttonHoverSpeed } }
              }

              MouseArea {
                id: shutdownHover
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { shutdownProc.running = false; shutdownProc.running = true }
                hoverEnabled: true
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

    // calendar popup box
    Rectangle {
      id: calendarPopup
      property bool shown: false
      visible: shown
      opacity: shown ? 1 : 0
      width: 225
      height: 187
      x: (parent.width - calendarPopup.width) / 2
      y: box.y + box.height + 5
      color: "#1e1e1e"
      radius: 15

      Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutExpo } }

      RowLayout {
        id: calHeader
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 12
        anchors.topMargin: 8
        height: 25

        Item { Layout.fillWidth: true }
 
        Text {
          text: datetimeItem.monthNames[datetimeItem.viewMonth] + " " + datetimeItem.viewYear
          color: Theme.fg
          font { family: Theme.fontFamily; pixelSize: 11; weight: 600 }
        }

        Item { Layout.fillWidth: true }

        }

      Grid {
        id: dayHeaders
        columns: 7
        anchors.top: calHeader.bottom
        anchors.topMargin: 6
        anchors.horizontalCenter: parent.horizontalCenter
        columnSpacing: 4
        Repeater {
          model: datetimeItem.dayNames
          Text {
            width: 25; text: modelData; color: "#666"
            font { family: Theme.fontFamily; pixelSize: 8; weight: 600 }
            horizontalAlignment: Text.AlignHCenter
          }
        }
      }

      Grid {
        columns: 7
        anchors.top: dayHeaders.bottom
        anchors.topMargin: 4
        anchors.horizontalCenter: parent.horizontalCenter
        columnSpacing: 4; rowSpacing: 2

        Repeater {
          model: datetimeItem.firstDayOfMonth(datetimeItem.viewYear, datetimeItem.viewMonth)
          Item { width: 26; height: 22 }
        }
        Repeater {
          model: datetimeItem.daysInMonth(datetimeItem.viewYear, datetimeItem.viewMonth)
          delegate: Rectangle {
            width: 26; height: 22; radius: 6
            property bool isToday: {
              var today = new Date()
              return index + 1 === today.getDate()
                && datetimeItem.viewMonth === today.getMonth()
                && datetimeItem.viewYear === today.getFullYear()
            }
            color: isToday ? "#e83131" : "transparent"
            Text {
              anchors.centerIn: parent
              text: index + 1
              color: isToday ? "#1e1e1e" : Theme.fg
              font { family: Theme.fontFamily; pixelSize: 9; weight: isToday ? 700 : 400 }
            }
          }
        }
      }
    }

    // open calendar when click on date in mini dashboard
    Connections {
      target: datetimeItem
      function onToggleCalendar() {
        console.log("toggleCalendar launched, current opacity:", calendarPopup.opacity)
        calendarPopup.shown = !calendarPopup.shown
      }
    }

  }
}


