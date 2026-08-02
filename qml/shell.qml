import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Widgets
import Quickshell.Services.UPower
import Quickshell.Services.Notifications

ShellRoot {

  IpcHandler {
      target: "cliphist"
      function toggle(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = !box.cliphistOpen; box.appLauncher = false }
      function show(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = true }
      function hide(): void { box.cliphistOpen = false }
  }

  IpcHandler {
      target: "controlCenter"
      function toggle(): void { box.controlCenter = !box.controlCenter; box.miniDashboard = false; box.cliphistOpen = false; box.appLauncher = false }
      function show(): void { box.controlCenter = true; box.miniDashboard = false; box.cliphistOpen = false }
      function hide(): void { box.controlCenter = false }
  }

  IpcHandler {
      target: "miniDashboard"
      function toggle(): void { box.controlCenter = false; box.miniDashboard = !box.miniDashboard; box.cliphistOpen = false; box.appLauncher = false }
      function show(): void { box.controlCenter = false; box.miniDashboard = true; box.cliphistOpen = false }
      function hide(): void { box.miniDashboard = false }
  }

  IpcHandler {
    target: "appLauncher"
    function toggle(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = false; box.appLauncher = !box.appLauncher }
    function show(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = false; box.appLauncher = true }
    function hide(): void { box.appLauncher = false }
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

  property bool notifFullscreenMode: false
  property bool fullscreenActive: ToplevelManager.activeToplevel && ToplevelManager.activeToplevel.fullscreen

  // osd ui
  property int osdInWidth: 120
  property real osdInHeight: 3.7
  property int osdBarRadius: 2
  property int osdSpeed: 60 // how fast bar fill/unfill
  property int osdWidth: 220
  property int osdHeight: 40

  readonly property int notifMaxHeight: 97

  // media player related
  property bool mediaAutoOpened: false

  PanelWindow {

    WlrLayershell.layer: WlrLayershell.Top
    WlrLayershell.keyboardFocus: (box.cliphistOpen || box.appLauncher) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    implicitHeight: 482

    anchors {
      top: true
      left: true
      right: true
    }

    margins {
      top: Config.pillTopMargin
    }

    // fixed gap of the active window for the top bar
    exclusiveZone: Config.pillBottomMargin
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
      Region {
          intersection: Intersection.Combine
          x: weatherPopupLoader.item ? Math.floor(weatherPopupLoader.item.x) : 0
          y: weatherPopupLoader.item ? Math.floor(weatherPopupLoader.item.y) : 0
          width: weatherPopupLoader.item && weatherPopupLoader.item.shown ? Math.ceil(weatherPopupLoader.item.width) : 0
          height: weatherPopupLoader.item && weatherPopupLoader.item.shown ? Math.ceil(weatherPopupLoader.item.height) : 0
      }
    }

    // main dynamic pill bar
    Rectangle {
      id: box
      anchors.top: parent.top
      anchors.horizontalCenter: parent.horizontalCenter
      opacity: (!fullscreenActive && !notifFullscreenMode) ? 1 : 0
      visible: opacity > 0
      clip: true

      property bool appLauncher: false
      property bool hovered: false
      property bool miniDashboard: false
      property bool controlCenter: false
      property bool cliphistOpen: false

      property var battery: UPower.displayDevice
      property bool charging: battery.state === UPowerDeviceState.Charging

      readonly property string batteryIconColor: box.charging || box.batteryLevel > 30 ? "#4bd25c"
         : box.batteryLevel <= 15 ? "#e22323"
         : "#eecc47"

      readonly property int batteryLevel: Math.round(battery.percentage * 100)

      // get battery icon according percentage
      readonly property string batteryIcon: {
        const icons = [0xf0083, 0xf007a, 0xf007d, 0xf007c, 0xf007d, 0xf007e, 0xf007f, 0xf0082, 0xf0081, 0xf0079]
        const base = String.fromCodePoint(icons[Math.min(Math.floor(batteryLevel / 10), 9)])
        return charging ? base + String.fromCodePoint(0xf140b) : base
      }

      onChargingChanged: {
        if (!box.controlCenter) box.activeOsd = "battery"
        osdHideTimer.interval = Config.osdDuration
        osdHideTimer.restart()
        console.log("charging:", box.charging, "level:", box.batteryLevel)
      }

      property string accent: Theme.accent

      // control center UI
      property real ccButtonBorderWidth: 1
      property string ccButtonBorderColor: "#202020"
      property int ccButtonWidth: 112
      property int ccButtonHeight: 35
      property int ccButtonRadius: 10
      property string ccButtonBgOff: "#151515"
      property string ccButtonFgOff: "#a4a4a4"
      property int sliderHeight: 4
      property int sliderRadius: 4
      property string sliderColor: "#c9c9c9"
      // invisible extra clickable area above/below the thin slider bars
      // (proportional to the bar height, so it scales with sliderHeight)
      property int sliderHitSlop: sliderHeight * 2
      property int mprisControlsIconSize: 20

      property string activeOsd: "" // volume, brightness, timer, battery

      Process { id: brightnessSetProc; running: false }

      Timer {
        id: osdHideTimer
        onTriggered: box.activeOsd = ""
      }
      Timer { id: brightnessThrottle; interval: 80; repeat: false }

      onImplicitHeightChanged: {
          heightAnim.stop()
          heightAnim.to = implicitHeight
          heightAnim.duration = mediaAutoOpened ? 650 : 550
          heightAnim.start()
      }

      readonly property int notifBump: notificationModule.notifications.length > 0
        ? Math.min(notifList.contentHeight + 40, 130) : 0

      // adjust box shape conditionally
      implicitWidth: box.activeOsd === "battery" ? osdWidth
                     : box.activeOsd === "timer" ? osdWidth
                     : (notificationModule.active && !notifFullscreenMode) ? 305
                     : controlCenter && mediaAutoOpened ? 380
                     : controlCenter ? 390
                     : activeOsd === "volume" ? osdWidth
                     : box.activeOsd === "brightness" ? osdWidth
                     : appLauncher ? 400
                     : miniDashboard ? 420
                     : cliphistOpen ? 460
                     : row.implicitWidth + (12 * Config.paddingScale) + (hovered ? 68 : 56) * Config.paddingScale

      implicitHeight: activeOsd === "battery" ? osdHeight
                  : activeOsd === "timer" ? osdHeight
                  : (notificationModule.active && !notifFullscreenMode) ? 52
                  : controlCenter && mprisModule.hasPlayer && mediaAutoOpened
                      ? 124
                  : controlCenter && mprisModule.hasPlayer
                      ? (240 + notifBump)
                  : controlCenter
                      ? (118 + notifBump)
                  : activeOsd === "volume" ? osdHeight
                  : activeOsd === "brightness" ? osdHeight
                  : cliphistOpen ? 270
                  : miniDashboard ? 155
                  : appLauncher ? 400
                  : (row.implicitHeight * Config.pillScale) + 10

      radius: notificationModule.active ? 99
        : cliphistOpen ? 28
        : controlCenter && mprisModule.hasPlayer ? 23
        : controlCenter && (notificationModule.notifications.length > 0) ? 25
        : appLauncher ? 30
        : miniDashboard ? 20
        : 20 * Config.pillScale

      Behavior on radius {
          NumberAnimation { duration: 225; easing.type: Easing.OutExpo }
      }
      color: controlCenter && mprisModule.hasPlayer ? "#1a1a1a" : bg

      onMiniDashboardChanged: {
        if (!miniDashboard) calendarPopup.shown = false; weatherPopupLoader.item.shown = false
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

          // mini dashboard accept only right
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
            box.appLauncher = false
            mediaPopupHideTimer.stop()
          }

          if (mouse.button === Qt.MiddleButton) {
            console.log("Middle click detected, opening cliphist")
            mediaAutoOpened = false
            box.appLauncher = false
            box.cliphistOpen = !box.cliphistOpen
          }

          if (mouse.button === Qt.RightButton) {
              console.log("Right click detected, opening mini dashboard")
              mediaAutoOpened = false
              box.appLauncher = false
              box.miniDashboard = !box.miniDashboard
          }
        }
      }

      Brightness {
          id: brightnessModule
          visible: false
          onBrightnessUpdated: {
              if (!box.controlCenter) box.activeOsd = "brightness"
              osdHideTimer.interval = Config.osdDuration
              osdHideTimer.restart()
          }
      }

      // modulues in bar
      RowLayout {
        id: row
        anchors.centerIn: parent
        anchors.leftMargin: 28
        anchors.rightMargin: 28
        spacing: 13 * Config.paddingScale
        opacity: !box.cliphistOpen
                 && !notificationModule.active
                 && !box.controlCenter
                 && !box.miniDashboard
                 && box.activeOsd === ""
                 && !box.appLauncher ? 1 : 0
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: 100 } }

        Battery {}
        Volume {
          id: volumeModule
          onVolumeChanged: {
            if (!box.controlCenter) box.activeOsd = "volume"
            osdHideTimer.interval = Config.osdDuration
            osdHideTimer.restart()
            }
        }
        Workspaces {}
        Network {}
        Clock {}
      }

      // volume
      OsdBar {
          active: box.activeOsd === "volume"
          icon: volumeModule.icon
          iconColor: volumeModule.muted ? volumeModule.mutedFg : Theme.fg
          percent: volumeModule.vol / 100
          muted: volumeModule.muted
          barWidth: volumeModule.mutedFg ? 90 : 110
          valueText: volumeModule.muted ? "muted" : volumeModule.vol + "%"
      }

      // brightness
      OsdBar {
          active: box.activeOsd === "brightness"
          icon: brightnessModule.icon
          percent: brightnessModule.percent
          valueText: Math.round(brightnessModule.percent * 100) + "%"
          barWidth: 100
      }

      // battery
      OsdBar {
        active: box.activeOsd === "battery"
        icon: box.batteryIcon
        iconColor: box.batteryIconColor
        valueText: box.charging ? "Charging" : "Charging stopped"
        barWidth: 0
        spacing: 5 // gap between battery icon and text
      }

      // timer end
      OsdBar {
        active: box.activeOsd === "timer"
        icon: String.fromCodePoint(0xf1ad1)
        iconColor: "#5892f3"
        valueText: "Timer finished"
        barWidth: 0
        spacing: 5
      }

      // notification
      NotificationPopup {
        active: notificationModule.active
                && !notifFullscreenMode
                && box.activeOsd === ""
        notif: notificationModule.current
      }

      // cliphist opens on middle click
      Item {
        anchors.centerIn: parent
        width: box.implicitWidth - 26
        height: box.cliphistOpen ? box.implicitHeight - 26 : 0
        opacity: box.cliphistOpen
                 && !notificationModule.active
                 && box.activeOsd === ""
                 && !box.controlCenter ? 1 : 0
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

      // app launcher opens through IPC
      Item {
          anchors.centerIn: parent
          width: box.implicitWidth - 28
          height: box.appLauncher ? 372 : 0
          opacity: box.appLauncher
                   && !notificationModule.active
                   && box.activeOsd === ""
                   && !box.controlCenter
                   && !box.miniDashboard
                   && !box.cliphistOpen ? 1 : 0
          visible: opacity > 0

          Behavior on opacity {
              SequentialAnimation {
                  PauseAnimation { duration: box.appLauncher ? 15 : 0 }
                  NumberAnimation { duration: 150; easing.type: Easing.OutExpo }
              }
          }

          Loader {
              anchors.fill: parent
              active: box.appLauncher
              asynchronous: true

              sourceComponent: AppLauncher {
                  shown: box.appLauncher
                  onCloseRequested: box.appLauncher = false
              }
          }
      }

      // control center opens on left click
      Item {
        anchors.centerIn: parent
        width: box.implicitWidth - 24
        opacity: box.controlCenter && box.activeOsd === "" && !notificationModule.active ? 1 : 0
        visible: opacity > 0
        height: box.controlCenter && box.activeOsd === "" ? box.implicitHeight - 25 : 0

        Behavior on opacity {
          SequentialAnimation {
            PauseAnimation { duration: box.controlCenter ? 15 : 0 }
            NumberAnimation { duration: 150; easing.type: Easing.OutExpo }
          }
        }

        // media player
        MediaPlayer {
          margin: box.controlCenter && mediaAutoOpened ? 5 : 14
          artistFontSize: 10
          artistFontWeight: box.controlCenter && mediaAutoOpened ? 500 : 300
          artistFontColor: box.controlCenter && mediaAutoOpened ? "#9b9b9b" : "#7b7b7b"
          color: box.controlCenter && mediaAutoOpened ? "#1a1a1a" : "#151515"
          radius: box.controlCenter && mprisModule.hasPlayer ? 16 : 25
          border.width: box.controlCenter && mediaAutoOpened ? 0 : 1
        }

        // control center buttons
        CcButtons {
          buttonBorderColor: box.ccButtonBorderColor
          buttonBorderWidth: box.ccButtonBorderWidth
          buttonWidth: box.ccButtonWidth
          buttonHeight: box.ccButtonHeight
          buttonRadius: box.ccButtonRadius
          buttonBgOff: box.controlCenter && !mprisModule.hasPlayer ? "#222222" : box.ccButtonBgOff
          buttonFgOff: box.controlCenter && !mprisModule.hasPlayer ? "#999999" : box.ccButtonFgOff
          controlCenterOpen: box.controlCenter
          mediaAutoOpened: mediaAutoOpened
          hasPlayer: mprisModule.hasPlayer
          playerHeight: box.ccButtonHeight
          notificationPopup: notificationModule.active
        } 

        // control center sliders
        Column {
          id: sliderColumn
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.topMargin: mprisModule.hasPlayer ? box.ccButtonHeight + 137 : 50
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
              font.family: Theme.nerdFontFamily
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
                // negative margins extend the clickable area beyond the thin bar
                anchors.topMargin: -box.sliderHitSlop
                anchors.bottomMargin: -box.sliderHitSlop
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
              font.family: Theme.nerdFontFamily
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
                // negative margins extend the clickable area beyond the thin bar
                anchors.topMargin: -box.sliderHitSlop
                anchors.bottomMargin: -box.sliderHitSlop
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

      // notifications stack popped header
      Rectangle {
        id: headerBar
        anchors.top: notifBox.top
        anchors.topMargin: -21
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 10
        height: 35
        topLeftRadius: 13
        topRightRadius: 13
        bottomLeftRadius: 0
        bottomRightRadius: 0
        color: "#2f2f2f"
        visible: notifBox.visible
        z: 0

        Item {
          Layout.fillWidth: true
          height: 16

          Text {
            text: "Notifications (" + notificationModule.notifications.length + ")"
            color: "#dddddd"
            font { family: Theme.fontFamily; pixelSize: 9; weight: 400 }
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.topMargin: 4
            anchors.verticalCenter: parent.verticalCenter
          }

          Rectangle {
            width: 60
            height: 16
            radius: 10
            color: clearAllHover.containsMouse ? "#1d1d1d" : "#242424"
            Behavior on color { ColorAnimation { duration: 100 } }
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 3
            anchors.rightMargin: -345

            Text {
              text: "Clear all"
              color: "#dedede"
              font { family: Theme.fontFamily; pixelSize: 8; weight: 300 }
              anchors.centerIn: parent
            }

            MouseArea {
              id: clearAllHover
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: notificationModule.clearAll()
            }
          }
        }
      }

      // notifications list stack
      Rectangle {
        id: notifBox
        anchors.top: sliderColumn.bottom
        anchors.topMargin: 32
        anchors.bottomMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 10
        height: Math.min(notifList.contentHeight + 7, notifMaxHeight)
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: 13
        bottomRightRadius: 13
        color: "#161616"
        visible: notificationModule.notifications.length > 0 && box.controlCenter && !mediaAutoOpened
        clip: true
        border.width: 1
        border.color: "#2f2f2f"
        z: 1

        Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

        ListView {
          id: notifList
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.topMargin: 5
          anchors.leftMargin: 5
          anchors.rightMargin: 5
          height: Math.min(contentHeight, notifMaxHeight)
          spacing: 6
          model: notificationModule.notificationsReversed
          clip: true
          interactive: contentHeight > height
          flickDeceleration: 3000
          maximumFlickVelocity: 2500
          boundsBehavior: Flickable.StopAtBounds

          // cache delegates instead of recreating on scroll
          cacheBuffer: 200
          reuseItems: true

          ScrollBar.vertical: ScrollBar {
            id: notifScrollBar
            policy: ScrollBar.AlwaysOff
            visible: notifList.contentHeight > notifList.height
            width: 10
            anchors.rightMargin: 10
            z: 20
            contentItem: Rectangle {
              implicitWidth: 8
              radius: 10
              color: notifScrollBar.pressed ? "#888"
                   : scrollHover.hovered ? "#6f6f6f"
                   : "#3a3a3a"
              Behavior on color { ColorAnimation { duration: 100 } }
              HoverHandler { id: scrollHover }
            }
          }

          // add/append notifications in the stack
          delegate: Item {
            id: notifDelegate
            width: ListView.view.width
            height: contentColumn.implicitHeight + 7

            // glyph (nerd font) bell icon
            Text {
              id: bellIcon
              text: String.fromCodePoint(0xf0f3)
              color: Theme.fg
              font { family: Theme.nerdFontFamily; pixelSize: 16 }
              visible: notifIcon.status !== Image.Ready
              anchors.left: parent.left
              anchors.top: parent.top
              anchors.topMargin: 10
              anchors.leftMargin: 16
            }

            // custom appicon
            Image {
              id: notifIcon
              width: 22
              height: 22
              fillMode: Image.PreserveAspectFit
              asynchronous: true
              source: {
                if (modelData.image) return modelData.image
                if (modelData.appIcon) {
                  return modelData.appIcon.startsWith("/")
                    ? "file://" + modelData.appIcon
                    : "image://icon/" + modelData.appIcon
                }
                return ""
              }
              sourceSize: Qt.size(22, 22)
              visible: status === Image.Ready
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.topMargin: 10
              anchors.leftMargin: 15
            }

            ColumnLayout {
              id: contentColumn
              anchors.fill: parent
              anchors.leftMargin: 50
              anchors.rightMargin: 3
              anchors.bottomMargin: 20
              spacing: 1

              Item {
                Layout.fillHeight: true
                Layout.topMargin: 8
                visible: !bodyText.visible
              }

              // heading / summary
              RowLayout {
                Layout.fillWidth: true

                Text {
                  text: modelData.summary
                  color: Theme.fg
                  font { family: Theme.fontFamily; pixelSize: 11; weight: 600 }
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }

                Text {
                  text: modelData.receivedTime ? Qt.formatTime(modelData.receivedTime, "hh:mm") : ""
                  color: "#858585"
                  font { family: Theme.fontFamily; pixelSize: 8 }
                  Layout.bottomMargin: 5
                }

                // close button
                Rectangle {
                  Layout.preferredWidth: 22
                  Layout.preferredHeight: 22
                  radius: 99
                  color: dismissHover.containsMouse ? "#333333" : "transparent"
                  Behavior on color { ColorAnimation { duration: 100 } }

                  Text {
                    text: ""
                    color: dismissHover.containsMouse ? "#bebebe" : "#404040"
                    anchors.centerIn: parent
                    font.pixelSize: 11
                    Behavior on color { ColorAnimation { duration: 150 } }
                  }

                  MouseArea {
                    id: dismissHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: notificationModule.dismiss(modelData._id)
                  }
                }
              }

              // description / body
              Text {
                id: bodyText
                text: modelData.body
                color: "#9f9f9f"
                font { family: Theme.fontFamily; pixelSize: 9; weight: 300 }
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                Layout.bottomMargin: 2
                visible: text !== ""
              }

              Item {
                Layout.fillHeight: true
                Layout.bottomMargin: 6
                visible: !bodyText.visible
              }
            }

            // divider
            Rectangle {
              anchors.bottom: parent.bottom
              width: parent.width
              height: 1
              color: "#333"
              visible: index < notificationModule.notifications.length - 1
            }
          }
        }
      }
      }

      // mini dashboard opens on right click
      Item {
        anchors.centerIn: parent
        width: box.implicitWidth - 30
        height: box.miniDashboard ? box.implicitHeight - 30 : 0  // don't fight the animation
        opacity: box.miniDashboard
                 && !notificationModule.active
                 && box.activeOsd === ""
                 && !box.cliphistOpen ? 1 : 0

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
          // profile picture (display picture)
          ClippingRectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            width: avatarSize
            height: avatarSize
            radius: avatarSize / 2
            color: "transparent"

            Image {
              id: avatarImg
              anchors.fill: parent
              source: "file://" + Config.displayPicture
              fillMode: Image.PreserveAspectCrop
              asynchronous: false
              sourceSize: Qt.size(avatarSize, avatarSize)
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

          // hostname
          Process {
            id: hostnameProc
            command: ["sh", "-c", "cat /etc/hostname"]
            running: true
            stdout: StdioCollector {
              onStreamFinished: { hostnameText.text = "(" + this.text.trim() + ")"; hostnameProc.running = false }
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

            RowLayout {
              Text {
                id: whoamiText
                color: Theme.fg
                Layout.leftMargin: 10
                font { family: Theme.fontFamily; pixelSize: 13; weight: 600 }
              }

              Text {
                id: hostnameText
                color: "#848484"
                Layout.topMargin: 2
                font { family: Theme.fontFamily; pixelSize: 9; weight: 300 }
              }
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

        // internet protocol information
        IpStatus {
          anchors.left: parent.left
          anchors.leftMargin: 5
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 42
        }

        // bandwidth usage status
        Bandwidth {
          anchors.right: parent.right
          anchors.rightMargin: 4
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 42
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
          anchors.topMargin: 97

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

              Process { id: lockProc; command: ["bash", "-c", Config.screenLockAppCommand]; running: false }
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

            Datetime { id: datetimeItem; dateFg: "#aaaaaa"; }

            Item { Layout.fillWidth: true }

            WeatherIndicator { id: weatherIndicatorItem }

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

    Loader {
        id: weatherPopupLoader
        active: false
        asynchronous: false

        sourceComponent: WeatherPopup {
            onShownChanged: if (!shown) closeTimer.start()
        }

        onLoaded: item.shown = true
        Timer {
            id: closeTimer
            interval: 250
            onTriggered: weatherPopupLoader.active = false
        }
    }

    // open calendar when click on date in mini dashboard
    Connections {
      target: datetimeItem
      function onToggleCalendar() {
        console.log("toggleCalendar launched, current opacity:", calendarPopup.opacity)
        calendarPopup.shown = !calendarPopup.shown
        weatherPopupLoader.item.shown = false
      }
    }

    // open weather when click on weather in mini dashboard
    Connections {
      target: weatherIndicatorItem
      function onToggleWeather() {
        if (!weatherPopupLoader.active)
          weatherPopupLoader.active = true
        else
          weatherPopupLoader.item.shown = !weatherPopupLoader.item.shown
        calendarPopup.shown = false
      }
    }

    Connections {
        target: mprisModule
        function onNowPlaying() {
          if (box.cliphistOpen || box.miniDashboard) return
          if (!box.controlCenter) mediaAutoOpened = true
          box.controlCenter = true
          mediaPopupHideTimer.restart()
        }
    }

    Timer {
        id: mediaPopupHideTimer
        interval: Config.mediaAutoOpenDuration
        repeat: false
        onTriggered: {
          if (mediaAutoOpened) {
            box.controlCenter = false
            mediaAutoOpened = false
          }
        }
    }

    Connections {
      target: countdownModule
      function onTimerFinished() {
        if (!box.controlCenter) box.activeOsd = "timer"
        osdHideTimer.interval = 2500
        osdHideTimer.restart()
      }
    }
  }

  Mpris { id: mprisModule; visible: false }

  CountdownModule { id: countdownModule; visible: false }

  NotificationServer {
    id: notifServer
    keepOnReload: false
    onNotification: notif => {
      notif.tracked = true
      notificationModule.enqueue(notif)
    }
  }

  NotificationModule { id: notificationModule; visible: false }

  FullscreenOsd {
    id: fsNotif
    active: notificationModule.active && notifFullscreenMode
    visible: notifFullscreenMode
    cardWidth: 300
    cardHeight: 52

    property var displayNotif: null

    RowLayout {
      anchors.centerIn: parent
      spacing: 12

      Text {
        text: String.fromCodePoint(0xf0f3)
        color: Theme.fg
        font { family: Theme.nerdFontFamily; pixelSize: 14 }
        visible: cardIcon.status !== Image.Ready
      }

      Image {
        id: cardIcon
        width: 23; height: 23
        fillMode: Image.PreserveAspectCrop
        source: {
          if (fsNotif.displayNotif && fsNotif.displayNotif.image) return fsNotif.displayNotif.image
          if (fsNotif.displayNotif && fsNotif.displayNotif.appIcon) {
            return fsNotif.displayNotif.appIcon.startsWith("/")
              ? "file://" + fsNotif.displayNotif.appIcon
              : "image://icon/" + fsNotif.displayNotif.appIcon
          }
          return ""
        }
        sourceSize: Qt.size(23, 23)
        visible: status === Image.Ready
      }

      ColumnLayout {
        spacing: 3

        Text {
          text: fsNotif.displayNotif ? fsNotif.displayNotif.summary : ""
          color: Theme.fg
          font { family: Theme.fontFamily; pixelSize: 10; weight: 700 }
          elide: Text.ElideRight
          Layout.maximumWidth: 200
        }

        Text {
          text: fsNotif.displayNotif ? fsNotif.displayNotif.body : ""
          color: "#9b9b9b"
          font { family: Theme.fontFamily; pixelSize: 9 }
          elide: Text.ElideRight
          visible: text !== ""
          Layout.maximumWidth: 200
        }
      }
    }
  }

  Connections {
    target: notificationModule
    function onActiveChanged() {
        if (notificationModule.active) {
            notifFullscreenMode = fullscreenActive
        } else {
            notifFullscreenMode = false
        }
    }
    function onCurrentChanged() {
      if (notificationModule.current) fsNotif.displayNotif = notificationModule.current
    }
  }

}
