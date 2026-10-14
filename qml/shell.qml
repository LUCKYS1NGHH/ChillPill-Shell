import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell.Widgets
import Quickshell.Services.UPower
import Quickshell.Services.Notifications

ShellRoot {
  id: shellRoot

  IpcHandler {
      target: "cliphist"
      function toggle(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = !box.cliphistOpen; box.spotlight = false; box.wallpaperSwitcherOpen = false; box.powerMenu = false }
      function show(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = true; box.powerMenu = false; }
      function hide(): void { box.cliphistOpen = false }
  }

  IpcHandler {
      target: "controlCenter"
      function toggle(): void { box.controlCenter = !box.controlCenter; box.miniDashboard = false; box.cliphistOpen = false; box.spotlight = false; box.wallpaperSwitcherOpen = false; box.powerMenu = false }
      function show(): void { box.controlCenter = true; box.miniDashboard = false; box.cliphistOpen = false; box.powerMenu = false; }
      function hide(): void { box.controlCenter = false }
  }

  IpcHandler {
      target: "miniDashboard"
      function toggle(): void { box.controlCenter = false; box.miniDashboard = !box.miniDashboard; box.cliphistOpen = false; box.spotlight = false; box.wallpaperSwitcherOpen = false; box.powerMenu = false }
      function show(): void { box.controlCenter = false; box.miniDashboard = true; box.cliphistOpen = false; box.wallpaperSwitcherOpen = false; box.powerMenu = false; }
      function hide(): void { box.miniDashboard = false }
  }

  // alias for spotlight
  IpcHandler {
    target: "appLauncher"
    function toggle(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = false; box.spotlight = !box.spotlight; box.wallpaperSwitcherOpen = false; box.powerMenu = false }
    function show(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = false; box.spotlight = true; box.powerMenu = false; }
    function hide(): void { box.spotlight = false; box.wallpaperSwitcherOpen = false }
  }

  IpcHandler {
    target: "spotlight"
    function toggle(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = false; box.spotlight = !box.spotlight; box.wallpaperSwitcherOpen = false; box.powerMenu = false }
    function show(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = false; box.spotlight = true; box.powerMenu = false; }
    function hide(): void { box.spotlight = false; box.wallpaperSwitcherOpen = false }
  }

  IpcHandler {
    target: "wallpaperSwitcher"
    function toggle(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = false; box.spotlight = false; box.wallpaperSwitcherOpen = !box.wallpaperSwitcherOpen; box.powerMenu = false }
    function show(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = false; box.spotlight = false; box.wallpaperSwitcherOpen = true; box.powerMenu = false; }
    function hide(): void { box.spotlight = false; box.wallpaperSwitcherOpen = false }
  }

  IpcHandler {
    target: "powerMenu"
    function toggle(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = false; box.spotlight = false; box.wallpaperSwitcherOpen = false; box.powerMenu = !box.powerMenu; if (!box.powerMenu) box.powerMenuInitialAction = "" }
    function show(): void { box.controlCenter = false; box.miniDashboard = false; box.cliphistOpen = false; box.spotlight = false; box.wallpaperSwitcherOpen = false; box.powerMenu = true }
    function hide(): void { box.powerMenu = false; box.powerMenuInitialAction = "" }
  }

  function capitalize(str) {
      return str.charAt(0).toUpperCase() + str.slice(1)
  }

  property bool pillHoverActive: false

  // Fix: Ignore audio/battery connection noise for 3 seconds on system boot
  Timer {
    id: bootGuardTimer
    interval: 3000
    running: true
    repeat: false
  }

  property string bg: Theme.bg
  property string fg: Theme.fg
  property string fontFamily: Theme.fontFamily
  property int avatarSize: 48
  property int buttonSize: 20
  property string buttonBg: Theme.bg5
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
  // toggle off -> the pill never grows for the popup, even if a track changed
  readonly property bool mediaPopupShown: Config.iNeedMediaPlayingPopup && mediaAutoOpened
  // flipping the toggle off collapses the pill right away
  onMediaPopupShownChanged: {
    if (!mediaPopupShown) {
      mediaAutoOpened = false
      mediaPopupHideTimer.stop()
    }
  }
  property var visualizerValues: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  property bool cavaAvailable: false
  // the pill bar's "audioVisualizer" module draws the same spectrum, so cava has
  // to run while the pill is revealed too (not just for the control center)
  readonly property bool pillHasVisualizer: (Config.pillModules || []).some(
    m => m === "audioVisualizer")

  Process {
    id: cavaCheckProc
    command: ["sh", "-c", "which cava"]
    running: true
    onExited: (exitCode) => { shellRoot.cavaAvailable = (exitCode === 0) }
  }

  PanelWindow {
    id: panelWindow
    WlrLayershell.layer: WlrLayershell.Top
    WlrLayershell.keyboardFocus: (box.cliphistOpen || box.spotlight || box.wallpaperSwitcherOpen || box.powerMenu) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    implicitHeight: Math.max(885 * scale, calendarLoader.item && calendarLoader.item.visible
            ? calendarLoader.y + calendarLoader.item.height : 0)
    onScreenChanged: console.log("dpi:", screen.devicePixelRatio)
    property real scale: screen ? screen.devicePixelRatio : 1.0

    anchors {
      top: true
      left: true
      right: true
    }

    // reserve top space only while the pill is shown
    margins.top: box.revealed ? Config.pillTopMargin : 0
    exclusiveZone: box.revealed ? Config.pillBottomMargin : 0
    color: "transparent"

    // Mask input to only the capsule
    mask: Region {
      Region {
        intersection: Intersection.Combine
        x: Math.floor(box.x - box.width * (box.dpi - 1) / 2); y: Math.floor(box.y)
        width: Math.ceil(box.width * box.dpi); height: Math.ceil(box.height * box.dpi)
      }
      // top band to catch the cursor while the pill is hidden in pillOnHover
      Region {
        intersection: Intersection.Combine
        x: 0; y: 0
        width: (Config.pillOnHover && !box.revealed) ? Math.ceil(panelWindow.width) : 0
        height: (Config.pillOnHover && !box.revealed) ? Math.ceil(hoverRevealAreaItem.height) : 0
      }
      Region {
        intersection: Intersection.Combine
        x: calendarLoader.item ? Math.floor(calendarLoader.x + calendarLoader.item.x) : 0
        y: calendarLoader.item ? Math.floor(calendarLoader.y + calendarLoader.item.y) : 0
        width: calendarLoader.item && calendarLoader.item.shown ? Math.ceil(calendarLoader.item.width) : 0
        height: calendarLoader.item && calendarLoader.item.shown ? Math.ceil(calendarLoader.item.height) : 0
      }
      Region {
          intersection: Intersection.Combine
          x: weatherPopupLoader.item ? Math.floor(weatherPopupLoader.item.x) : 0
          y: weatherPopupLoader.item ? Math.floor(weatherPopupLoader.item.y) : 0
          width: weatherPopupLoader.item && weatherPopupLoader.item.shown ? Math.ceil(weatherPopupLoader.item.width) : 0
          height: weatherPopupLoader.item && weatherPopupLoader.item.shown ? Math.ceil(weatherPopupLoader.item.height) : 0
      }
    }

    // reveal the pill when hovering the top edge in pillOnHover mode.
    // the band leaves the input mask once the pill is shown, so it cannot
    // stay stuck under the pill and block auto-hide
    Item {
      id: hoverRevealAreaItem
      anchors {
        top: parent.top
        topMargin: -Math.round(Config.pillTopMargin)
        left: parent.left
        right: parent.right
      }
      height: Math.max(box.implicitHeight + Config.pillTopMargin + 8, 48)

      HoverHandler {
        id: revealHover
        onHoveredChanged: {
          if (hovered) { shellRoot.pillHoverActive = true; hidePillTimer.stop() }
          else if (!pillHover.hovered) hidePillTimer.start()
        }
      }
    }

    Timer {
      id: hidePillTimer
      interval: 250
      onTriggered: shellRoot.pillHoverActive = false
    }

    // shadow under the pill, drawn as its own item so the pill itself stays
    // unlayered (a layer would re-render it at unscaled size and blur it)
    Item {
      id: pillShadow
      readonly property real pad: 24
      readonly property real drop: 5 * box.dpi
      readonly property real visX: box.x - box.width * (box.dpi - 1) / 2
      readonly property real visW: box.width * box.dpi
      x: visX - pad
      y: box.y - pad
      width: visW + pad * 2
      height: box.height * box.dpi + pad * 2.2
      opacity: box.opacity
      visible: Config.showShadows && box.visible && opacity > 0

      Rectangle {
        id: pillShadowSource
        x: pillShadow.pad
        y: pillShadow.pad + pillShadow.drop
        width: pillShadow.visW
        height: pillShadow.height - pillShadow.pad * 2.2 - pillShadow.drop
        radius: box.radius * box.dpi
        color: "#b0000000"

        layer.enabled: true
        layer.smooth: true
        layer.mipmap: true
        layer.effect: MultiEffect {
          blurEnabled: true
          blur: 1.0
          blurMax: 30
          blurMultiplier: 1.6
        }
      }
    }

    // main dynamic pill bar
    Rectangle {
      id: box
      anchors.top: parent.top
      anchors.horizontalCenter: parent.horizontalCenter
      readonly property bool revealed: !Config.pillOnHover
        || shellRoot.pillHoverActive
        || controlCenter
        || miniDashboard
        || cliphistOpen
        || spotlight
        || wallpaperSwitcherOpen
        || powerMenu
        || mediaPopupShown
        || (notificationModule.active && !notifFullscreenMode)
        || (activeOsd !== "")
      opacity: revealed && (!fullscreenActive && !notifFullscreenMode) ? 1 : 0

      Behavior on opacity {
        NumberAnimation { duration: 220; easing.type: Easing.OutExpo }
      }

      visible: opacity > 0
      clip: true

      property var volumeModule: null
      property var networkModule: null
      property var bluetoothModule: null
      property var clockModule: clock
      property var vpnModule: null

      property bool tooltipVisible: false
      property string tooltipModule: ""
      property string customTooltipText: ""
      property real tooltipX: 0
      property real tooltipY: 0

      property bool spotlight: false
      // the calendar is only built while it is (or is fading out) visible
      property bool calendarShown: false
      // spotlight is heavy (app cache), so it is only built the first time it is
      // opened and dropped a while after it closes again
      readonly property int spotlightUnloadDelay: 60000
      property bool spotlightLoaded: false
      onSpotlightChanged: {
        if (spotlight) {
          spotlightLoaded = true
          spotlightUnloadTimer.stop()
        } else {
          spotlightUnloadTimer.restart()
        }
      }

      Timer {
        id: spotlightUnloadTimer
        interval: box.spotlightUnloadDelay
        onTriggered: box.spotlightLoaded = false
      }
      property bool hovered: false
      property bool miniDashboard: false
      property bool controlCenter: false
      property bool cliphistOpen: false
      property bool wallpaperSwitcherOpen: false
      property bool cliphistPreviewing: false
      property bool powerMenu: false
      property string powerMenuInitialAction: ""

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
      property string ccButtonBgOff: Theme.bg2
      property string ccButtonFgOff: Theme.fg2
      property int sliderHeight: 4
      property int sliderRadius: 4
      property string sliderColor: Theme.sliderBg
      // invisible extra clickable area above/below the thin slider bars
      // (proportional to the bar height, so it scales with sliderHeight)
      property int sliderHitSlop: sliderHeight * 2
      property int mprisControlsIconSize: 20

      property string activeOsd: "" // volume, brightness, timer, battery

      // Fix: Instantly filter out and clear any initial audio/battery connection noise during boot
      onActiveOsdChanged: {
        if (bootGuardTimer.running && activeOsd !== "") {
          activeOsd = ""
        }
      }

      Timer {
        id: osdHideTimer
        onTriggered: box.activeOsd = ""
      }

      onImplicitHeightChanged: {
          // follow spotlight live while typing (stacked height animations wobble); animate open/close jumps
          heightAnim.stop()
          if (box.spotlight && Math.abs(implicitHeight - height) < 120) {
              height = implicitHeight
          } else {
              heightAnim.to = implicitHeight
              heightAnim.duration = shellRoot.mediaPopupShown ? 650 : 550
              heightAnim.start()
          }
      }

      readonly property int notifBump: notificationModule.notifications.length > 0
        ? Math.min(ccPanel.notifBump, 130) : 0

      // adjust pill shape conditionally (pill state)
      readonly property real dpi: Config.dpiScale

      readonly property real baseWidth: activeOsd === "battery" ? osdWidth
                     : activeOsd === "timer" ? osdWidth
                     : activeOsd === "volume" ? osdWidth
                     : activeOsd === "brightness" ? osdWidth
                     : (notificationModule.active && !notifFullscreenMode) ? 320
                     : powerMenu ? 350
                     : controlCenter ? 390
                     : spotlight ? 350
                     : miniDashboard ? 420
                     : (cliphistOpen && cliphistPreviewing) ? 400
                     : wallpaperSwitcherOpen ? 600
                     : cliphistOpen ? 440
                     : mediaPopupShown ? 335
                     : row.implicitWidth + (12 * Config.pillScale) + (Config.pillOnHover || !hovered ? 56 : 68) * Config.pillScale

      readonly property real baseHeight: activeOsd === "battery" ? osdHeight
                  : activeOsd === "timer" ? osdHeight
                  : activeOsd === "volume" ? osdHeight
                  : activeOsd === "brightness" ? osdHeight
                  : (notificationModule.active && !notifFullscreenMode) ? 52
                  : powerMenu ? 102
                  : controlCenter && mprisModule.hasPlayer
                      ? (240 + notifBump)
                  : controlCenter
                      ? (118 + notifBump)
                  : (cliphistOpen && cliphistPreviewing) ? 380
                  : miniDashboard ? 155
                  : spotlight
                      ? (spotlightLoader.item ? spotlightLoader.item.height + 15 : 250)
                  : wallpaperSwitcherOpen ? 308
                  : cliphistOpen ? 276
                  : mediaPopupShown ? 94
                  : (row.implicitHeight * Config.pillScale) + 10

      readonly property real baseRadius: notificationModule.active ? 99
        : cliphistOpen && cliphistPreviewing ? 33
        : cliphistOpen ? 28
        : controlCenter ? (notificationModule.notifications.length > 0
          ? (mprisModule.hasPlayer ? 27 : 25)
          : (mprisModule.hasPlayer ? 26 : 22))
        : spotlight ? 29
        : miniDashboard ? 20
        : wallpaperSwitcherOpen ? 30
        : activeOsd !== "" ? 20
        : powerMenu ? 22
        : mediaPopupShown ? 23
        : 20 * Config.pillScale

      implicitWidth: baseWidth
      implicitHeight: baseHeight
      radius: baseRadius
      scale: dpi
      transformOrigin: Item.Top

      Behavior on radius {
          NumberAnimation { duration: 225; easing.type: Easing.OutExpo }
      }

      color: bg

      onCalendarShownChanged: if (calendarLoader.item) calendarLoader.item.shown = box.calendarShown

      onMiniDashboardChanged: {
          if (!box.miniDashboard) {
              box.calendarShown = false
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

          if (mediaPopupShown) return

          // clicking outside power menu buttons closes it
          if (box.powerMenu) {
            box.powerMenu = false
            box.powerMenuInitialAction = ""
            return
          }

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
            box.spotlight = false
            box.wallpaperSwitcherOpen = false
            box.powerMenu = false
            box.powerMenuInitialAction = ""
            mediaPopupHideTimer.stop()
          }

          if (mouse.button === Qt.MiddleButton) {
            console.log("Middle click detected, opening cliphist")
            mediaAutoOpened = false
            box.spotlight = false
            box.wallpaperSwitcherOpen = false
            box.powerMenu = false
            box.powerMenuInitialAction = ""
            box.cliphistOpen = !box.cliphistOpen
          }

          if (mouse.button === Qt.RightButton) {
              console.log("Right click detected, opening mini dashboard")
              mediaAutoOpened = false
              box.spotlight = false
              box.wallpaperSwitcherOpen = false
              box.powerMenu = false
              box.powerMenuInitialAction = ""
              box.miniDashboard = !box.miniDashboard
          }
        }
      }

      // keeps the pill shown while hovered and hides it when the cursor leaves
      HoverHandler {
        id: pillHover
        target: box
        onHoveredChanged: {
          if (hovered) { shellRoot.pillHoverActive = true; hidePillTimer.stop() }
          else if (!revealHover.hovered) hidePillTimer.start()
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

      // bar modules and their tooltip
      PillBarModules { id: row }
      TooltipPopup { id: tooltipPopup }

      // volume
      OsdBar {
          active: box.activeOsd === "volume"
          icon: box.volumeModule ? box.volumeModule.icon : ""
          iconColor: box.volumeModule && box.volumeModule.muted ? box.volumeModule.mutedFg : Theme.fg
          percent: box.volumeModule ? Math.min(box.volumeModule.intendedVol / Config.maxVolume, 1.0) : 0
          muted: box.volumeModule ? box.volumeModule.muted : false
          barWidth: box.volumeModule && box.volumeModule.mutedFg ? 80 : 90
          valueText: box.volumeModule ? (box.volumeModule.muted ? "muted" : box.volumeModule.intendedVol + "%") : ""
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
        width: box.cliphistOpen ? box.implicitWidth - 16 : 0
        height: box.cliphistOpen ? box.implicitHeight - 16 : 0
        opacity: box.cliphistOpen
                 && !notificationModule.active
                 && box.activeOsd === ""
                 && !box.controlCenter
                 && !box.powerMenu ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
          SequentialAnimation {
            PauseAnimation { duration: box.cliphistOpen ? 15 : 0 }
            NumberAnimation { duration: 150; easing.type: Easing.OutExpo }
          }
        }

        Loader {
          id: cliphistLoader
          anchors.fill: parent
          active: box.cliphistOpen
          asynchronous: true

          sourceComponent: Cliphist {
            id: cliphistPanel
            shown: box.cliphistOpen
            onCloseRequested: box.cliphistOpen = false
            onPreviewToggled: (active) => box.cliphistPreviewing = active
          }
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
                 && !box.controlCenter
                 && !box.miniDashboard
                 && !box.cliphistOpen
                 && !box.spotlight
                 && !box.powerMenu ? 1 : 0
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

      // spotlight (formerly app launcher) opens through IPC
      Item {
          anchors.centerIn: parent
          width: box.implicitWidth - 16
          // height follows spotlight (shrinks with results)
          height: spotlightLoader.item ? spotlightLoader.item.height : 388
          opacity: box.spotlight
                   && !notificationModule.active
                   && box.activeOsd === ""
                   && !box.controlCenter
                   && !box.miniDashboard
                   && !box.cliphistOpen
                   && !box.powerMenu ? 1 : 0
          visible: opacity > 0

          Behavior on opacity {
              SequentialAnimation {
                  PauseAnimation { duration: box.spotlight ? 15 : 0 }
                  NumberAnimation { duration: 150; easing.type: Easing.OutExpo }
              }
          }

          Loader {
              id: spotlightLoader
              width: parent.width
              anchors.horizontalCenter: parent.horizontalCenter
              // built on the first open, then kept alive so its app cache/height persist
              // between opens (avoids the open-time fallback -> empty -> full resize race)
              active: box.spotlightLoaded
              asynchronous: true

              sourceComponent: Spotlight {
                  shown: box.spotlight
                  onCloseRequested: box.spotlight = false
              }
          }
      }

      // power menu
      Item {
          anchors.centerIn: parent
          width: box.implicitWidth - 25
          height: box.powerMenu ? box.implicitHeight - 18 : 0
          opacity: box.powerMenu
                   && !notificationModule.active
                   && box.activeOsd === ""
                   && !box.controlCenter
                   && !box.miniDashboard
                   && !box.cliphistOpen
                   && !box.spotlight
                   && !box.wallpaperSwitcherOpen ? 1 : 0
          visible: opacity > 0

          Behavior on opacity {
              SequentialAnimation {
                  PauseAnimation { duration: box.powerMenu ? 15 : 0 }
                  NumberAnimation { duration: 150; easing.type: Easing.OutExpo }
              }
          }

          Loader {
              id: powerMenuLoader
              anchors.fill: parent
              active: box.powerMenu
              asynchronous: true

              sourceComponent: PowerMenu {
                  shown: box.powerMenu
                  initialAction: box.powerMenuInitialAction
                  onCloseRequested: {
                      box.powerMenu = false
                      box.powerMenuInitialAction = ""
                  }
              }
              onLoaded: item.forceActiveFocus()
          }

          Connections {
              target: box
              function onPowerMenuChanged() {
                  if (box.powerMenu && powerMenuLoader.item) {
                      powerMenuLoader.item.initialAction = box.powerMenuInitialAction
                      powerMenuLoader.item.forceActiveFocus()
                  } else if (!box.powerMenu) {
                      box.powerMenuInitialAction = ""
                  }
              }
          }
      }

      // media popup
      Item {
          anchors.fill: parent
          opacity: box.activeOsd === ""
                   && !notificationModule.active
                   && !box.controlCenter
                   && !box.cliphistOpen
                   && !box.miniDashboard
                   && !box.spotlight
                   && !box.wallpaperSwitcherOpen
                   && !box.powerMenu
                   ? 1 : 0
          visible: opacity > 0

          Loader {
              anchors.centerIn: parent
              active: shellRoot.mediaPopupShown
              asynchronous: true

              sourceComponent: MediaPopup {
                  active: shellRoot.mediaPopupShown
              }
          }
      }

      // control center opens on left click
      Item {
        anchors.centerIn: parent
        width: box.implicitWidth - 24
        opacity: box.controlCenter && box.activeOsd === "" && !notificationModule.active && !box.powerMenu ? 1 : 0
        visible: opacity > 0
        height: box.controlCenter && box.activeOsd === "" ? box.implicitHeight - 25 : 0

        Behavior on opacity {
          SequentialAnimation {
            PauseAnimation { duration: box.controlCenter ? 15 : 0 }
            NumberAnimation { duration: 150; easing.type: Easing.OutExpo }
          }
        }

        ControlCenterPanel {
          id: ccPanel
          anchors.fill: parent
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
                 && !box.cliphistOpen
                 && !box.powerMenu ? 1 : 0
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

        // only exists while the mini dashboard is open
        Loader {
          id: miniDashboardLoader
          anchors.fill: parent
          active: box.miniDashboard
          asynchronous: true

          sourceComponent: MiniDashboard {}
        }
      }
      SystemClock {
        id: clock
        precision: SystemClock.Minutes
      }
    }

    // built on the first open, then freed once it has faded out
    Loader {
      id: calendarLoader
      x: (parent.width - 225 * box.dpi) / 2      // centering lives here now
      y: box.y + box.height * box.dpi + 5 * box.dpi  // stays live while the pill animates
      active: box.calendarShown || (item && item.opacity > 0)
      asynchronous: true

      sourceComponent: CalendarBox {}
      onLoaded: item.shown = box.calendarShown
    }

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
      target: miniDashboardLoader.item
      function onToggleCalendar() {
        box.calendarShown = !box.calendarShown
        if (box.calendarShown && calendarLoader.item) calendarLoader.item.resetView()
        if (weatherPopupLoader.item) weatherPopupLoader.item.shown = false
      }
    }

    // open weather when click on weather in mini dashboard
    Connections {
      target: miniDashboardLoader.item
      function onToggleWeather() {
        if (mediaPopupShown) return
        if (!weatherPopupLoader.active)
          weatherPopupLoader.active = true
        else
          weatherPopupLoader.item.shown = !weatherPopupLoader.item.shown
        box.calendarShown = false
      }
    }

    Connections {
        target: mprisModule
        function onNowPlaying() {
            if (!Config.iNeedMediaPlayingPopup) return
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

  // volume OSD over fullscreen windows
  FullscreenOsd {
    id: fsVolume
    active: box.activeOsd === "volume"
      && fullscreenActive
      && !notifFullscreenMode
    cardWidth: 220 * box.dpi
    cardHeight: 42 * box.dpi

    readonly property var volModule: box.volumeModule

    RowLayout {
      Layout.alignment: Qt.AlignVCenter
      spacing: 12 * box.dpi

      Text {
        text: fsVolume.volModule ? fsVolume.volModule.icon : ""
        color: fsVolume.volModule && fsVolume.volModule.muted ? fsVolume.volModule.mutedFg : Theme.fg
        font { family: Theme.nerdFontFamily; pixelSize: 16 * box.dpi }
      }

      // same bar geometry and fill speed as the pill OSD
      Rectangle {
        width: 90 * box.dpi
        height: 4 * box.dpi
        radius: 2 * box.dpi
        color: Theme.bg1
        Layout.alignment: Qt.AlignVCenter

        Rectangle {
          width: parent.width * (fsVolume.volModule ? Math.min(fsVolume.volModule.intendedVol / Config.maxVolume, 1.0) : 0)
          height: parent.height
          radius: parent.radius
          color: fsVolume.volModule && fsVolume.volModule.muted ? fsVolume.volModule.mutedFg : Theme.fg
          Behavior on width { NumberAnimation { duration: osdSpeed; easing.type: Easing.OutCubic } }
        }
      }

      Text {
        text: fsVolume.volModule ? (fsVolume.volModule.muted ? "muted" : fsVolume.volModule.intendedVol + "%") : ""
        color: Theme.fg
        font { family: Theme.fontFamily; pixelSize: 10 * box.dpi; weight: 600 }
        Layout.alignment: Qt.AlignVCenter
      }
    }
  }

  // brightness OSD over fullscreen windows
  FullscreenOsd {
    id: fsBrightness
    active: box.activeOsd === "brightness" && fullscreenActive && !notifFullscreenMode
    cardWidth: 220 * box.dpi
    cardHeight: 42 * box.dpi

    RowLayout {
      Layout.alignment: Qt.AlignVCenter
      spacing: 12 * box.dpi

      Text {
        text: brightnessModule.icon
        color: Theme.fg
        font { family: Theme.nerdFontFamily; pixelSize: 16 * box.dpi }
      }

      // same bar geometry and fill speed as the pill OSD
      Rectangle {
        width: 100 * box.dpi
        height: 4 * box.dpi
        radius: 2 * box.dpi
        color: Theme.bg1
        Layout.alignment: Qt.AlignVCenter

        Rectangle {
          width: parent.width * brightnessModule.percent
          height: parent.height
          radius: parent.radius
          color: Theme.fg
          Behavior on width { NumberAnimation { duration: osdSpeed; easing.type: Easing.OutCubic } }
        }
      }

      Text {
        text: Math.round(brightnessModule.percent * 100) + "%"
        color: Theme.fg
        font { family: Theme.fontFamily; pixelSize: 10 * box.dpi; weight: 600 }
        Layout.alignment: Qt.AlignVCenter
      }
    }
  }

  // audio visualizer spectrum process
  Process {
    id: cavaProc
    command: ["sh", "-c", "cava -p ~/.cache/chillpill-shell/cava.conf"]
    running: shellRoot.cavaAvailable
             && ((Config.showAudioVisuals && box.controlCenter)
                 || (box.revealed && shellRoot.pillHasVisualizer))
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
