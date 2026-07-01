import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import IslandBackend

ShellRoot {

  IpcHandler {
      target: "cliphist"

      function toggle(): void {
          box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = !box.cliphistOpen }

      function show(): void {
          box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = true }

      function hide(): void {
          box.cliphistOpen = false
      }
  }

  IpcHandler {
      target: "controlCenter"

      function toggle(): void {
          box.controlCenter = !box.controlCenter; box.miniDashboard = false; box.cliphistOpen = false }

      function show(): void {
          box.controlCenter = true; box.miniDashboard = false; box.cliphistOpen = false }

      function hide(): void {
          box.controlCenter = false
      }
  }

  IpcHandler {
      target: "miniDashboard"

      function toggle(): void {
          box.controlCenter = false; box.miniDashboard = !box.miniDashboard; box.cliphistOpen = false }

      function show(): void {
          box.controlCenter = false; box.miniDashboard = true; box.cliphistOpen = false }

      function hide(): void {
        box.miniDashboard = false
      }
  }

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

  // media player related
  property bool mediaAutoOpened: false

  PanelWindow {

    WlrLayershell.keyboardFocus: box.cliphistOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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
      clip: true

      property bool hovered: false
      property bool miniDashboard: false
      property bool volumeActive: false
      property bool brightnessActive: false
      property bool controlCenter: false
      property bool cliphistOpen: false

      property string accent: Theme.accent

      // control center UI
      property int ccButtonWidth: 95
      property int ccButtonHeight: 55
      property int ccButtonRadius: 10
      property int sliderHeight: 4
      property int sliderRadius: 4
      property string sliderColor: "#c9c9c9"
      property int mprisControlsIconSize: 20

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

      Process {
        id: brightnessSetProc
        running: false
      }

      Timer {
        id: brightnessThrottle
        interval: 80
        repeat: false
      }

      onImplicitHeightChanged: {
          heightAnim.stop()
          heightAnim.to = implicitHeight
          heightAnim.duration = mediaAutoOpened ? 650 : 550
          heightAnim.start()
      }

      implicitWidth: controlCenter && mediaAutoOpened ? 380
                     : controlCenter ? 390
                     : volumeActive ? 220
                     : brightnessActive ? 220
                     : cliphistOpen ? 450
                     : miniDashboard ? 420
                     : row.implicitWidth + (hovered ? 68 : 56)

      implicitHeight: controlCenter && mprisModule.hasPlayer && mediaAutoOpened ? 124
                      : controlCenter && mprisModule.hasPlayer ? 202
                      : controlCenter ? 74
                      : volumeActive ? 40
                      : brightnessActive ? 40
                      : cliphistOpen ? 270
                      : miniDashboard ? 120
                      : row.implicitHeight + (hovered ? 10 : 10)

      radius: cliphistOpen ? 25 : controlCenter && mprisModule.hasPlayer ? 23 : controlCenter ? 12 : 20
      color: controlCenter && mprisModule.hasPlayer ? "#1a1a1a" : bg

      onMiniDashboardChanged: {
        if (!miniDashboard) calendarPopup.shown = false
      }

      Behavior on implicitWidth { NumberAnimation { duration: 225; easing.type: Easing.OutExpo } }
      NumberAnimation { id: heightAnim; target: box; property: "height"; easing.type: Easing.OutExpo }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onEntered: box.hovered = true
        onExited: box.hovered = false

        onClicked: (mouse) => {

          // restrict control center to only accept left click
          if (box.controlCenter) {
            if (mouse.button === Qt.LeftButton)
              box.controlCenter = false
            return
          }

          // same, cliphist accept middle
          if (box.cliphistOpen) {
            if (mouse.button === Qt.MiddleButton) {
              box.cliphistOpen = false
            }
            return
          }

          // last, mini dashboard accept only left
          if (box.miniDashboard) {
            if (mouse.button === Qt.RightButton) {
              box.miniDashboard = false
            }
            return
          }

          if (mouse.button === Qt.LeftButton) {
            console.log("Left click detected, opening control center")
            box.controlCenter = !box.controlCenter
            mediaAutoOpened = false
            mediaPopupHideTimer.stop()
          }

          if (mouse.button === Qt.MiddleButton) {
            console.log("Middle click detected, opening cliphist")
            mediaAutoOpened = false
            box.cliphistOpen = !box.cliphistOpen
          }

          if (mouse.button === Qt.RightButton) {
              console.log("Right click detected, opening mini dashboard")
              mediaAutoOpened = false
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
        opacity: box.cliphistOpen ? 0 : box.controlCenter ? 0 : box.miniDashboard ? 0 : box.volumeActive ? 0 : box.brightnessActive ? 0 : 1

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

      OsdBar {
          active: box.volumeActive && !box.controlCenter
          icon: volumeModule.icon
          percent: volumeModule.vol / 100
          muted: volumeModule.muted
          mutedFg: volumeModule.mutedFg
          valueText: volumeModule.muted ? "muted" : volumeModule.vol + "%"
      }

      OsdBar {
          active: box.brightnessActive && !box.volumeActive && !box.controlCenter
          icon: brightnessModule.icon
          percent: brightnessModule.percent
          valueText: Math.round(brightnessModule.percent * 100) + "%"
      }

      // cliphist opens on middle click
      Item {
        anchors.centerIn: parent
        width: box.implicitWidth - 24
        height: box.cliphistOpen ? box.implicitHeight - 25 : 0
        opacity: box.cliphistOpen && !mediaAutoOpened && !box.volumeActive && !box.brightnessActive && !box.controlCenter ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
          SequentialAnimation {
            PauseAnimation { duration: box.cliphistOpen ? 15 : 0 }
            NumberAnimation { duration: 150; easing.type: Easing.OutExpo }
          }
        }

        Cliphist {
          id: cliphistPanel
          shown: box.cliphistOpen
          anchors.fill: parent
          onCloseRequested: box.cliphistOpen = false
        }
      }

      // control center opens on left click
      Item {
        anchors.centerIn: parent
        width: box.implicitWidth - 24
        opacity: box.controlCenter && !box.cliphistOpen && !box.miniDashboard && box.controlCenter ? 1 : 0
        visible: opacity > 0
        height: box.controlCenter ? box.implicitHeight - 25 : 0

        Behavior on opacity {
          SequentialAnimation {
            PauseAnimation { duration: box.controlCenter ? 15 : 0 }
            NumberAnimation { duration: 150; easing.type: Easing.OutExpo }
          }
        }

        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton

          onClicked: (mouse) => {
              if (mouse.button === Qt.LeftButton)
                box.controlCenter = !box.controlCenter
                mediaAutoOpened = true
                mediaPopupHideTimer.stop()
          }
        }

        // media player
        MediaPlayer {
          margin: box.controlCenter && mediaAutoOpened ? 5 : 14
          artistFontSize: box.controlCenter && mediaAutoOpened ? 10 : 9
          artistFontWeight: box.controlCenter && mediaAutoOpened ? 500 : 400
          artistFontColor: box.controlCenter && mediaAutoOpened ? "#9b9b9b" : "#7b7b7b"
          color: box.controlCenter && mediaAutoOpened ? "#1a1a1a" : "#151515"
          radius: box.controlCenter && mprisModule.hasPlayer ? 16 : 25
          border.width: box.controlCenter && mediaAutoOpened ? 0 : 1
        }

        // sliders
        Column {
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.topMargin: mprisModule.hasPlayer ? box.ccButtonHeight + 77 : 4
          anchors.leftMargin: 15
          anchors.rightMargin: 2
          spacing: 5
          visible: !mediaAutoOpened

          // volume
          RowLayout {
            width: parent.width
            spacing: 14

            Text {
              text: volumeModule.icon
              color: volumeModule.muted ? "#fd2222" : Theme.fg
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 13
              anchors.leftMargin: 10
            }

            Rectangle {
              Layout.fillWidth: true
              height: box.sliderHeight
              radius: box.sliderRadius
              color: "#3a3a3a"

              Rectangle {
                width: parent.width * (volumeModule.vol / 100)
                height: parent.height
                radius: box.sliderRadius
                color: box.sliderColor
                Behavior on width { NumberAnimation { duration: 60 } }
              }

              MouseArea {
                anchors.fill: parent
                onClicked: (mouse) => {
                  volumeModule.sink.audio.volume = Math.max(0, Math.min(1, mouse.x / width))
                }
                onPositionChanged: (mouse) => {
                  if (pressed)
                    volumeModule.sink.audio.volume = Math.max(0, Math.min(1, mouse.x / width))
                }
              }
            }

            Text {
              text: volumeModule.muted ? "muted" : volumeModule.vol + "%"
              color: Theme.fg
              font.family: Theme.fontFamily
              font.pixelSize: 10
              Layout.minimumWidth: 35
            }
          }

          // brightness
          RowLayout {
            width: parent.width
            spacing: 14

            Text {
              text: brightnessModule.icon
              color: Theme.fg
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 13
            }

            Rectangle {
              Layout.fillWidth: true
              height: box.sliderHeight
              radius: box.sliderRadius
              color: "#3a3a3a"

              Rectangle {
                width: parent.width * brightnessModule.percent
                height: parent.height
                radius: box.sliderRadius
                color: box.sliderColor
                Behavior on width { NumberAnimation { duration: 60 } }
              }

              MouseArea {
                anchors.fill: parent
                onClicked: (mouse) => {
                  let pct = Math.round(Math.max(0, Math.min(1, mouse.x / width)) * 100)
                  brightnessSetProc.command = ["brightnessctl", "set", pct + "%"]
                  brightnessSetProc.running = false
                  brightnessSetProc.running = true
                }
                onPositionChanged: (mouse) => {
                  if (pressed && !brightnessThrottle.running) {
                    let pct = Math.round(Math.max(0, Math.min(1, mouse.x / width)) * 100)
                    brightnessSetProc.command = ["brightnessctl", "set", pct + "%"]
                    brightnessSetProc.running = false
                    brightnessSetProc.running = true
                    brightnessThrottle.start()
                  }
                }
              }
            }

            Text {
              text: Math.round(brightnessModule.percent * 100) + "%"
              color: Theme.fg
              font.family: Theme.fontFamily
              font.pixelSize: 10
              Layout.minimumWidth: 35
            }
          }
        } 
      }

      // mini dashboard opens on right click
      Item {
        anchors.centerIn: parent
        width: box.implicitWidth - 30
        height: box.miniDashboard ? box.implicitHeight - 30 : 0  // don't fight the animation
        opacity: box.miniDashboard && !mediaAutoOpened && !box.volumeActive && !box.brightnessActive && !box.cliphistOpen ? 1 : 0

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
              source: "file://" + Quickshell.env("HOME") + "/.pfp.png"
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
    CalendarBox { id: calendarPopup }

    // open calendar when click on date in mini dashboard
    Connections {
      target: datetimeItem
      function onToggleCalendar() {
        console.log("toggleCalendar launched, current opacity:", calendarPopup.opacity)
        calendarPopup.shown = !calendarPopup.shown
      }
    }

    Connections {
        target: mprisModule
        function onNowPlaying() {
          if (!box.controlCenter) {
            mediaAutoOpened  = true
          }
          box.controlCenter = true
          mediaPopupHideTimer.restart()
        }
    }

    Timer {
        id: mediaPopupHideTimer
        interval: 2000
        repeat: false
        onTriggered: {
          if (mediaAutoOpened) {
            box.controlCenter = false
            mediaAutoOpened = false
          }
        }
    }
 
  }

  Mpris { id: mprisModule; visible: false }

}
