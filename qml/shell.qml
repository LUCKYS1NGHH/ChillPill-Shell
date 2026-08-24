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
  id: shellRoot

  IpcHandler {
      target: "cliphist"
      function toggle(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = !box.cliphistOpen; box.appLauncher = false; box.wallpaperSwitcherOpen = false }
      function show(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = true; }
      function hide(): void { box.cliphistOpen = false }
  }

  IpcHandler {
      target: "controlCenter"
      function toggle(): void { box.controlCenter = !box.controlCenter; box.miniDashboard = false; box.cliphistOpen = false; box.appLauncher = false; box.wallpaperSwitcherOpen = false }
      function show(): void { box.controlCenter = true; box.miniDashboard = false; box.cliphistOpen = false; }
      function hide(): void { box.controlCenter = false }
  }

  IpcHandler {
      target: "miniDashboard"
      function toggle(): void { box.controlCenter = false; box.miniDashboard = !box.miniDashboard; box.cliphistOpen = false; box.appLauncher = false; box.wallpaperSwitcherOpen = false }
      function show(): void { box.controlCenter = false; box.miniDashboard = true; box.cliphistOpen = false; box.wallpaperSwitcherOpen = false }
      function hide(): void { box.miniDashboard = false }
  }

  IpcHandler {
    target: "appLauncher"
    function toggle(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = false; box.appLauncher = !box.appLauncher; box.wallpaperSwitcherOpen = false}
    function show(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = false; box.appLauncher = true; }
    function hide(): void { box.appLauncher = false; box.wallpaperSwitcherOpen = false }
  }

  IpcHandler {
    target: "wallpaperSwitcher"
    function toggle(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = false; box.appLauncher = false; box.wallpaperSwitcherOpen = !box.wallpaperSwitcherOpen }
    function show(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = false; box.appLauncher = false; box.wallpaperSwitcherOpen = true }
    function hide(): void { box.appLauncher = false; box.wallpaperSwitcherOpen = false }
  }

  property string bg: Theme.bg
  property string fg: Theme.fg
  property string fontFamily: Theme.fontFamily
  property int avatarSize: 48
  property int buttonSize: 20
  property string buttonBg: Theme.bg6
  property string buttonHoverBg: Theme.focusFg1
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
  property var visualizerValues: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  property bool cavaAvailable: false

  Process {
    id: cavaCheckProc
    command: ["sh", "-c", "which cava"]
    running: true
    onExited: (exitCode) => { shellRoot.cavaAvailable = (exitCode === 0) }
  }

  PanelWindow {
    id: panelWindow
    WlrLayershell.layer: WlrLayershell.Top
    WlrLayershell.keyboardFocus: (box.cliphistOpen || box.appLauncher || box.wallpaperSwitcherOpen) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    implicitHeight: Math.max(885 * scale, calendarPopup.visible ? calendarPopup.y + calendarPopup.height : 0)
    onScreenChanged: console.log("dpi:", screen.devicePixelRatio)
    property real scale: screen ? screen.devicePixelRatio : 1.0

    anchors {
      top: true
      left: true
      right: true
    }

    // fixed gap of the active window for the top bar
    margins.top: Config.pillTopMargin
    exclusiveZone: Config.pillBottomMargin
    color: "transparent"

    // Mask input to only the capsule
    mask: Region {
      Region {
        intersection: Intersection.Combine
        x: Math.floor(box.x - box.width * (box.dpi - 1) / 2); y: Math.floor(box.y)
        width: Math.ceil(box.width * box.dpi); height: Math.ceil(box.height * box.dpi)
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
      property bool wallpaperSwitcherOpen: false

      property var battery: UPower.displayDevice
      property bool hasBattery: battery.isLaptopBattery && battery.isPresent
      property bool charging: hasBattery && battery.state === UPowerDeviceState.Charging
      readonly property string batteryIconColor: box.charging || box.batteryLevel > 30 ? "#4bd25c" : box.batteryLevel <= 15 ? "#e22323" : "#eecc47"
      readonly property int batteryLevel: hasBattery ? Math.round(battery.percentage * 100) : 0
      // battery icon on laptops, plug icon on desktops
      readonly property string batteryIcon: {
        if (!hasBattery)
          return String.fromCodePoint(0xf06a5) + " " // nf-md-power_plug
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
      property real ccButtonWidth: 85.3
      property int ccButtonHeight: 35
      property int ccButtonRadius: 10
      property string ccButtonBgOff: Theme.bg1
      property string ccButtonFgOff: Theme.fg3
      property int sliderHeight: 4
      property int sliderRadius: 4
      property string sliderColor: Theme.sliderBg
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

      onImplicitHeightChanged: {
          heightAnim.stop()
          heightAnim.to = implicitHeight
          heightAnim.duration = mediaAutoOpened ? 650 : 550
          heightAnim.start()
      }

      readonly property int notifBump: notificationModule.notifications.length > 0
        ? Math.min(notifList.contentHeight + 40, 130) : 0

      // adjust box shape conditionally
      readonly property real dpi: Config.dpiScale

      property bool cliphistPreviewing: false

      readonly property real baseWidth: activeOsd === "battery" ? osdWidth
                     : activeOsd === "timer" ? osdWidth
                     : activeOsd === "volume" ? osdWidth
                     : activeOsd === "brightness" ? osdWidth
                     : (notificationModule.active && !notifFullscreenMode) ? 320
                     : controlCenter ? 390
                     : mediaAutoOpened ? 340
                     : appLauncher ? 390
                     : miniDashboard ? 420
                     : (cliphistOpen && cliphistPreviewing) ? 400
                     : cliphistOpen ? 460
                     : wallpaperSwitcherOpen ? 600
                     : row.implicitWidth + (12 * Config.paddingScale) + (hovered ? 68 : 56) * Config.paddingScale

      readonly property real baseHeight: activeOsd === "battery" ? osdHeight
                  : activeOsd === "timer" ? osdHeight
                  : activeOsd === "volume" ? osdHeight
                  : activeOsd === "brightness" ? osdHeight
                  : (notificationModule.active && !notifFullscreenMode) ? 52
                  : controlCenter && mprisModule.hasPlayer
                      ? (240 + notifBump)
                  : controlCenter
                      ? (118 + notifBump)
                  : mediaAutoOpened ? 90
                  : (cliphistOpen && cliphistPreviewing) ? 380
                  : cliphistOpen ? 270
                  : miniDashboard ? 155
                  : appLauncher ? 410
                  : wallpaperSwitcherOpen ? 308
                  : (row.implicitHeight * Config.pillScale) + 10

      readonly property real baseRadius: notificationModule.active ? 99
        : mediaAutoOpened ? 22
        : cliphistOpen && cliphistPreviewing ? 35
        : cliphistOpen ? 28
        : controlCenter ? (notificationModule.notifications.length > 0
          ? (mprisModule.hasPlayer ? 27 : 25)
          : (mprisModule.hasPlayer ? 26 : 22))
        : appLauncher ? 30
        : miniDashboard ? 20
        : wallpaperSwitcherOpen ? 30
        : 20 * Config.pillScale

      implicitWidth: baseWidth
      implicitHeight: baseHeight
      radius: baseRadius
      scale: dpi
      transformOrigin: Item.Top

      Behavior on radius {
          NumberAnimation { duration: 225; easing.type: Easing.OutExpo }
      }

      color: controlCenter ? Theme.bgD1 : bg

      onMiniDashboardChanged: {
          if (!box.miniDashboard) {
              calendarPopup.shown = false
              if (weatherPopupLoader.item) weatherPopupLoader.item.shown = false
          }
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

          if (mediaAutoOpened) return

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

          if (box.wallpaperSwitcherOpen) {
            if (mouse.button !== Qt.LeftButton) {
              return
            }
          }

          if (mouse.button === Qt.LeftButton) {
            console.log("Left click detected, opening control center")
            box.controlCenter = !box.controlCenter
            mediaAutoOpened = false
            box.appLauncher = false
            box.wallpaperSwitcherOpen = false
            mediaPopupHideTimer.stop()
          }

          if (mouse.button === Qt.MiddleButton) {
            console.log("Middle click detected, opening cliphist")
            mediaAutoOpened = false
            box.appLauncher = false
            box.wallpaperSwitcherOpen = false
            box.cliphistOpen = !box.cliphistOpen
          }

          if (mouse.button === Qt.RightButton) {
              console.log("Right click detected, opening mini dashboard")
              mediaAutoOpened = false
              box.appLauncher = false
              box.wallpaperSwitcherOpen = false
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

      // modules in bar
      RowLayout {
        id: row
        anchors.centerIn: parent
        anchors.leftMargin: 28
        anchors.rightMargin: 28
        spacing: 13 * Config.paddingScale
        opacity: !box.cliphistOpen
                 && !notificationModule.active
                 && !mediaAutoOpened
                 && !box.controlCenter
                 && !box.miniDashboard
                 && box.activeOsd === ""
                 && !box.wallpaperSwitcherOpen
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
        height: (box.cliphistOpen ? box.implicitHeight - 26 : 0) + cliphistExtraHeight
        opacity: box.cliphistOpen
                 && !notificationModule.active
                 && box.activeOsd === ""
                 && !mediaAutoOpened
                 && !box.controlCenter ? 1 : 0
        visible: opacity > 0

        property real cliphistExtraHeight: 0

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
          onPreviewToggled: (active) => box.cliphistPreviewing = active
        }
      }

      // wallpaper switcher
      Item {
        anchors.centerIn: parent
        width: box.implicitWidth - 28
        height: box.wallpaperSwitcherOpen ? 280 : 0
        opacity: box.wallpaperSwitcherOpen
                 && !notificationModule.active
                 && box.activeOsd === ""
                 && !mediaAutoOpened
                 && !box.controlCenter
                 && !box.miniDashboard
                 && !box.cliphistOpen
                 && !box.appLauncher ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
          SequentialAnimation {
            PauseAnimation { duration: box.wallpaperSwitcherOpen ? 15 : 0 }
            NumberAnimation { duration: 150; easing.type: Easing.OutExpo }
          }
        }
        Loader {
          id: wallpaperLoader
          anchors.fill: parent
          active: box.wallpaperSwitcherOpen
          asynchronous: true
          sourceComponent: WallpaperSwitcher {
            shown: box.wallpaperSwitcherOpen
            onCloseRequested: box.wallpaperSwitcherOpen = false
          }
          onLoaded: item.forceActiveFocus()
        }

        Connections {
          target: box
          function onWallpaperSwitcherOpenChanged() {
            if (box.wallpaperSwitcherOpen && wallpaperLoader.item)
              wallpaperLoader.item.forceActiveFocus()
          }
        }
      }

      // app launcher opens through IPC
      Item {
          anchors.centerIn: parent
          width: box.implicitWidth - 26
          height: box.appLauncher ? 384 : 0
          opacity: box.appLauncher
                   && !notificationModule.active
                   && box.activeOsd === ""
                   && !mediaAutoOpened
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

      // media popup
      Item {
          anchors.fill: parent
          opacity: box.activeOsd === "" && !notificationModule.active && !box.controlCenter ? 1 : 0
          visible: opacity > 0

          Loader {
              anchors.centerIn: parent
              active: mediaAutoOpened
              asynchronous: true

              sourceComponent: MediaPopup {
                  active: mediaAutoOpened
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
        MediaPlayer {}

        // control center buttons
        CcButtons {
          buttonWidth: box.ccButtonWidth
          buttonHeight: box.ccButtonHeight
          buttonRadius: box.ccButtonRadius
          buttonBgOff: box.ccButtonBgOff
          buttonFgOff: box.ccButtonFgOff
          controlCenterOpen: box.controlCenter
          mediaAutoOpened: mediaAutoOpened
          hasPlayer: mprisModule.hasPlayer
          playerHeight: box.ccButtonHeight
          notificationPopup: notificationModule.active
        } 

        CcSliders {
          id: sliderColumn
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.topMargin: mprisModule.hasPlayer ? box.ccButtonHeight + 137 : 50
          anchors.leftMargin: 15
          anchors.rightMargin: 2

          sliderHeight: box.sliderHeight
          sliderRadius: box.sliderRadius
          sliderColor: box.sliderColor
          sliderHitSlop: box.sliderHitSlop
          volIcon: volumeModule.icon
          volMuted: volumeModule.muted
          volPercent: volumeModule.vol
          brightnessIcon: brightnessModule.icon
          brightnessPercent: brightnessModule.percent

          onVolumeChangeRequested: (fraction) => {
            volumeModule.sink.audio.volume = Math.max(0, Math.min(1, fraction))
          }
          onBrightnessChangeRequested: (fraction) => {
            let pct = Math.round(Math.max(0, Math.min(1, fraction)) * 100)
            brightnessSetProc.command = ["brightnessctl", "set", pct + "%"]
            brightnessSetProc.running = false
            brightnessSetProc.running = true
          }
        }

      // notifications stack popped header
      Rectangle {
        id: headerBar
        anchors.top: notifBox.top
        anchors.topMargin: -20
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 10
        height: 20
        topLeftRadius: 13
        topRightRadius: 13
        bottomLeftRadius: 0
        bottomRightRadius: 0
        color: Theme.bg5
        visible: notifBox.visible
        z: 0

        Item {
          anchors.fill: parent

          Text {
            text: "Notifications (" + notificationModule.notifications.length + ")"
            color: Theme.fg2
            font { family: Theme.fontFamily; pixelSize: 9; weight: 400 }
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            verticalAlignment: Text.AlignVCenter
          }

          Rectangle {
            width: 60
            height: 16
            radius: 10
            color: clearAllHover.containsMouse ? Theme.bg : Theme.bg1
            Behavior on color { ColorAnimation { duration: 100 } }
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter

            Text {
              text: "Clear all"
              color: Theme.fg3
              font { family: Theme.fontFamily; pixelSize: 8; weight: 400 }
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
        color: Theme.bgD
        visible: notificationModule.notifications.length > 0 && box.controlCenter
        clip: true
        border.width: 1
        border.color: Theme.bg2
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
              enabled: true
              smooth: true
              mipmap: true
              sourceSize: Qt.size(22 * box.dpi, 22 * box.dpi)
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
                  textFormat: Text.PlainText
                  color: Theme.fg
                  font { family: Theme.fontFamily; pixelSize: 11; weight: 650 }
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }

                Text {
                  text: modelData.receivedTime ? Qt.formatTime(modelData.receivedTime, "hh:mm") : ""
                  color: Theme.fg5
                  font { family: Theme.fontFamily; pixelSize: 8 }
                  Layout.bottomMargin: 5
                }

                // close button
                Rectangle {
                  Layout.preferredWidth: 22
                  Layout.preferredHeight: 22
                  radius: 99
                  color: dismissHover.containsMouse ? Theme.focusBgL : "transparent"
                  Behavior on color { ColorAnimation { duration: 100 } }

                  Text {
                    text: ""
                    color: dismissHover.containsMouse ? Theme.focusFg1 : Theme.fg7
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
                text: modelData.body ? modelData.body.replace(
                  /\[([^\]]+)\]\(["']?([^)"']+)["']?\)/g,
                  '<a href="$2">$1</a>'
                ) : ""
                textFormat: Text.StyledText
                linkColor: Theme.accent
                color: Theme.fg4
                font { family: Theme.fontFamily; pixelSize: 9; weight: 400 }
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
              color: Theme.bg5
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
                 && !mediaAutoOpened
                 && !notificationModule.active
                 && box.activeOsd === ""
                 && !box.cliphistOpen ? 1 : 0
        visible: opacity > 0

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

        RowLayout {
         // profile picture (display picture)
           ClippingRectangle {
            id: avatarClip
            width: avatarSize
            height: avatarSize
            radius: avatarSize / 2
            property string imgPath: Config.displayPicture ? "file://" + Config.displayPicture.replace("~", Quickshell.env("HOME")) : ""
            color: (imgPath === "" || avatarImg.status !== Image.Ready) ? Theme.bg5 : "transparent"
            layer.enabled: true
            layer.smooth: true
            layer.mipmap: true
            layer.textureSize: Qt.size(avatarSize, avatarSize)

            Image {
              id: avatarImg
              anchors.fill: parent
              source: avatarClip.imgPath
              fillMode: Image.PreserveAspectCrop
              asynchronous: false
              smooth: true
              mipmap: true
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
                font { family: Theme.fontFamily; pixelSize: 14; weight: 600 }
              }

              Text {
                id: hostnameText
                color: Theme.fg5
                Layout.topMargin: 2
                font { family: Theme.fontFamily; pixelSize: 9; weight: 400 }
              }
            }

            Text {
              id: uptimeText
              color: Theme.fg4
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
          color: Theme.bg1
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

            Datetime { id: datetimeItem; dateFg: Theme.fg4; }

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
        if (weatherPopupLoader.item) weatherPopupLoader.item.shown = false
      }
    }

    // open weather when click on weather in mini dashboard
    Connections {
      target: weatherIndicatorItem
      function onToggleWeather() {
        if (mediaAutoOpened) return
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
            if (box.controlCenter) return
            if (!box.mediaPopup) mediaAutoOpened = true
            mediaPopupHideTimer.restart()
        }
    }

    Timer {
        id: mediaPopupHideTimer
        interval: Config.mediaPopupDuration
        repeat: false
        onTriggered: {
          if (mediaAutoOpened) mediaAutoOpened = false
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

  MprisModule { id: mprisModule; visible: false }

  CountdownModule { id: countdownModule; visible: false }

  NotificationServer {
    id: notifServer
    keepOnReload: false
    imageSupported: true
    actionsSupported: true
    actionIconsSupported: true
    bodySupported: true
    bodyMarkupSupported: true
    bodyHyperlinksSupported: true
    bodyImagesSupported: true
    persistenceSupported: true
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
    cardWidth: 300 * box.dpi
    cardHeight: 52 * box.dpi

    property var displayNotif: null

    RowLayout {
      Layout.alignment: Qt.AlignVCenter
      spacing: 12 * box.dpi

      Text {
        text: String.fromCodePoint(0xf0f3)
        color: Theme.fg
        font { family: Theme.nerdFontFamily; pixelSize: 14 * box.dpi }
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
        sourceSize: Qt.size(23 * box.dpi, 23 * box.dpi)
        visible: status === Image.Ready
      }

      ColumnLayout {
        spacing: 3 * box.dpi

        Text {
          text: fsNotif.displayNotif ? fsNotif.displayNotif.summary : ""
          textFormat: Text.PlainText
          color: Theme.fg
          font { family: Theme.fontFamily; pixelSize: 10 * box.dpi; weight: 700 }
          elide: Text.ElideRight
          Layout.maximumWidth: 200
        }

        Text {
          text: fsNotif.displayNotif ? fsNotif.displayNotif.body.replace(
            /\[([^\]]+)\]\(["']?([^)"']+)["']?\)/g,
            '<a href="$2">$1</a>'
          ) : ""
          textFormat: Text.StyledText
          linkColor: Theme.accent
          color: Theme.fg4
          font { family: Theme.fontFamily; pixelSize: 9 * box.dpi }
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

  // audio visualizer spectrum process
  Process {
    id: cavaProc
    command: ["sh", "-c", "cava -p ~/.cache/chillpill-shell/cava.conf"]
    running: Config.showAudioVisuals && box.controlCenter && shellRoot.cavaAvailable
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => {
        let parts = data.trim().split(";")
        let vals = []
        for (let i = 0; i < 16; i++) {
          let v = Number(parts[i])
          vals.push(isNaN(v) ? 0 : Math.min(100, Math.max(0, v)))
        }
        shellRoot.visualizerValues = vals
      }
    }
  }

}
