//@ pragma UseQApplication
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
      function toggle(): void { box.controlCenter = false; box.dashboard = false; box.cliphistOpen = !box.cliphistOpen; box.spotlight = false; box.wallpaperSwitcherOpen = false; box.powerMenu = false; box.themePicker = false }
      function show(): void { box.controlCenter = false; box.dashboard = false; box.cliphistOpen = true; box.powerMenu = false; }
      function hide(): void { box.cliphistOpen = false }
  }

  IpcHandler {
      target: "controlCenter"
      function toggle(): void { box.controlCenter = !box.controlCenter; box.dashboard = false; box.cliphistOpen = false; box.spotlight = false; box.wallpaperSwitcherOpen = false; box.powerMenu = false; box.themePicker = false }
      function show(): void { box.controlCenter = true; box.dashboard = false; box.cliphistOpen = false; box.powerMenu = false; }
      function hide(): void { box.controlCenter = false }
  }

  IpcHandler {
      target: "dashboard"
      function toggle(): void { box.controlCenter = false; box.dashboard = !box.dashboard; box.cliphistOpen = false; box.spotlight = false; box.wallpaperSwitcherOpen = false; box.powerMenu = false; box.themePicker = false }
      function show(): void { box.controlCenter = false; box.dashboard = true; box.cliphistOpen = false; box.wallpaperSwitcherOpen = false; box.powerMenu = false; }
      function hide(): void { box.dashboard = false }
  }

  // alias for spotlight
  IpcHandler {
    target: "appLauncher"
    function toggle(): void { box.controlCenter = false; box.dashboard = false; box.cliphistOpen = false; box.spotlight = !box.spotlight; box.wallpaperSwitcherOpen = false; box.powerMenu = false; box.themePicker = false }
    function show(): void { box.controlCenter = false; box.dashboard = false; box.cliphistOpen = false; box.spotlight = true; box.powerMenu = false; }
    function hide(): void { box.spotlight = false; box.wallpaperSwitcherOpen = false }
  }

  IpcHandler {
    target: "theme"
    function toggle(): void { box.themePicker = !box.themePicker; box.controlCenter = false; box.dashboard = false; box.cliphistOpen = false; box.spotlight = false; box.wallpaperSwitcherOpen = false; box.powerMenu = false }
    function show(): void { box.themePicker = true; box.controlCenter = false; box.dashboard = false; box.cliphistOpen = false; box.spotlight = false; box.wallpaperSwitcherOpen = false; box.powerMenu = false }
    function hide(): void { box.themePicker = false }
    function apply(name: string): void { Theme.applyTheme(name) }
  }

  IpcHandler {
    target: "spotlight"
    function toggle(): void { box.controlCenter = false; box.dashboard = false; box.cliphistOpen = false; box.spotlight = !box.spotlight; box.wallpaperSwitcherOpen = false; box.powerMenu = false; box.themePicker = false }
    function show(): void { box.controlCenter = false; box.dashboard = false; box.cliphistOpen = false; box.spotlight = true; box.powerMenu = false; }
    function hide(): void { box.spotlight = false; box.wallpaperSwitcherOpen = false }
  }

  IpcHandler {
    target: "wallpaperSwitcher"
    function toggle(): void { box.controlCenter = false; box.dashboard = false; box.cliphistOpen = false; box.spotlight = false; box.wallpaperSwitcherOpen = !box.wallpaperSwitcherOpen; box.powerMenu = false; box.themePicker = false }
    function show(): void { box.controlCenter = false; box.dashboard = false; box.cliphistOpen = false; box.spotlight = false; box.wallpaperSwitcherOpen = true; box.powerMenu = false; }
    function hide(): void { box.spotlight = false; box.wallpaperSwitcherOpen = false }
  }

  IpcHandler {
    target: "powerMenu"
    function toggle(): void { box.controlCenter = false; box.dashboard = false; box.cliphistOpen = false; box.spotlight = false; box.wallpaperSwitcherOpen = false; box.powerMenu = !box.powerMenu; if (!box.powerMenu) box.powerMenuInitialAction = ""; box.themePicker = false }
    function show(): void { box.controlCenter = false; box.dashboard = false; box.cliphistOpen = false; box.spotlight = false; box.wallpaperSwitcherOpen = false; box.powerMenu = true }
    function hide(): void { box.powerMenu = false; box.powerMenuInitialAction = "" }
  }

  IpcHandler {
    target: "wifiState"
    function toggle(): void { box.dashboard = false; box.cliphistOpen = false; box.spotlight = false; box.wallpaperSwitcherOpen = false; box.powerMenu = false; box.bluetoothPanelOpen = false; box.wifiPanelOpen = !box.wifiPanelOpen; box.controlCenter = box.wifiPanelOpen; box.themePicker = false }
    function show(): void { box.controlCenter = true; box.dashboard = false; box.cliphistOpen = false; box.spotlight = false; box.wallpaperSwitcherOpen = false; box.powerMenu = false; box.bluetoothPanelOpen = false; box.wifiPanelOpen = true }
    function hide(): void { box.powerMenu = false; box.wifiPanelOpen = false }
  }

  IpcHandler {
    target: "bluetoothState"
    function toggle(): void { box.dashboard = false; box.cliphistOpen = false; box.spotlight = false; box.wallpaperSwitcherOpen = false; box.powerMenu = false; box.wifiPanelOpen = false; box.bluetoothPanelOpen = !box.bluetoothPanelOpen; box.controlCenter = box.bluetoothPanelOpen; box.themePicker = false }
    function show(): void { box.controlCenter = true; box.dashboard = false; box.cliphistOpen = false; box.spotlight = false; box.wallpaperSwitcherOpen = false; box.powerMenu = false; box.wifiPanelOpen = false; box.bluetoothPanelOpen = true }
    function hide(): void { box.powerMenu = false; box.bluetoothPanelOpen = false }
  }

  function capitalize(str) {
      return str.charAt(0).toUpperCase() + str.slice(1)
  }

  property bool pillHoverActive: false

  // clipboard image being dragged out of the full preview (null when idle);
  // x/y are window coords reported by the drag area via mapToItem(null)
  property var clipDragImage: null
  // drag is live (pointer still tracked by the panel) — guards the async
  // handoff so a drag that ends before the native start can't resurrect
  property bool clipDragLive: false
  // true once the drag crosses the pill edge and the native (browser/file
  // manager) drag takes over from the manual ghost
  property bool clipDragNative: false
  // drop action reported by Drag.dragFinished, Qt.IgnoreAction by default
  property int clipDragResult: Qt.IgnoreAction
  property url clipDragIcon: ""
  readonly property url clipDragUrl: clipDragImage ? "file://" + clipDragImage.path : ""
  // the ghost item, so panels can grab its thumbnail for the drag icon
  property Item dragGhost: null

  function beginNativeImageDrag() {
    if (clipDragNative || !clipDragLive || !clipDragImage) return
    dragGhost.grabToImage(function (result) {
      // the drag may have ended while the grab was in flight
      if (!clipDragLive || !clipDragImage) return
      clipDragIcon = result.url
      clipDragNative = true
    }, Qt.size(180, 130))
  }

  // a catcher (browser, file manager...) accepting the drop yields a real
  // drop action and nothing else happens; an ignored drop applies the
  // wallpaper unless the cursor came back over the pill (cancel)
  function finishClipDrag(dropAction) {
    let img = clipDragImage
    clipDragNative = false
    clipDragLive = false
    clipDragImage = null
    clipDragIcon = ""
    if (!img) return
    if (dropAction !== Qt.IgnoreAction) return
    dropTargetProbe.img = img
    dropTargetProbe.running = false
    dropTargetProbe.running = true
  }

  // cursor position at the moment of the drop, for the pill/cancel check
  Process {
    id: dropTargetProbe
    property var img: null
    command: ["sh", "-c", 'hyprctl cursorpos | tr -d " "']
    stdout: StdioCollector {
      onStreamFinished: {
        let img = dropTargetProbe.img
        dropTargetProbe.img = null
        if (!img) return
        let m = /^(\d+),(\d+)$/.exec(this.text.trim())
        if (!m) return
        let p = box.mapFromItem(null, Number(m[1]), Number(m[2]) - panelWindow.margins.top)
        if (p.x >= 0 && p.y >= 0 && p.x <= box.width && p.y <= box.height) return
        shellRoot.saveCurrentWallpaper(img.path)
        shellRoot.applyWallpaper(img.path)
        box.cliphistOpen = false
      }
    }
  }

  // true while the native drag is running (mirrors the ghost's Drag.active)
  readonly property bool clipDragActive: dragGhost ? dragGhost.Drag.active : false
  // if the drag ended but Drag.dragFinished never fired, finalize shortly after
  onClipDragActiveChanged: {
    if (clipDragActive || !clipDragNative || !clipDragImage) clipDragWatchdog.stop()
    else clipDragWatchdog.restart()
  }

  // Drag.dragFinished is the primary end signal; this catches platforms
  // where it doesn't fire so the state can't get stuck
  Timer {
    id: clipDragWatchdog
    interval: 250
    onTriggered: if (shellRoot.clipDragNative) shellRoot.finishClipDrag(shellRoot.clipDragResult)
  }

  // shared by the wallpaper switcher and the clipboard image drop target
  function applyWallpaper(path) {
    if (Config.customWallpaperScript.trim() === "") {
      Quickshell.execDetached(["awww", "img", "--transition-type", "random", path])
    }
    else {
      let script = Config.customWallpaperScript
      let cmd = script.includes("{path}")
          ? script.replace(/["']?\{path\}["']?/g, "\"$1\"")
          : script + " \"$1\"" // fallback for old-style configs without the placeholder
      Quickshell.execDetached(["sh", "-c", cmd, "_", path])
    }
  }

  function saveCurrentWallpaper(path) {
    // execDetached, not a Process child: callers may close panels right after,
    // which would kill a child Process before it ever runs
    Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && printf %s "$2" > "$1/last_wallpaper"',
      "_", Quickshell.env("HOME") + "/.cache/chillpill-shell", path])
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
    WlrLayershell.keyboardFocus: (box.wifiPanelOpen || box.bluetoothPanelOpen || box.cliphistOpen || box.spotlight || box.wallpaperSwitcherOpen || box.themePicker || box.powerMenu ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None)
    implicitHeight: 885 * scale
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
    color: Theme.transparent

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

    // ghost image following the cursor while a clipboard image is dragged
    // out of the full preview; kept unclipped at window level so it can
    // travel past the pill while dragging. Once the cursor leaves the pill
    // the same item becomes the source of a native drag (uri payload), so
    // the image can be dropped into browsers, file managers, etc.
    Image {
      id: clipDragGhost
      visible: shellRoot.clipDragImage !== null && !shellRoot.clipDragNative
      x: visible ? shellRoot.clipDragImage.x - width / 2 : 0
      y: visible ? shellRoot.clipDragImage.y - height / 2 : 0
      width: 220
      height: 150
      fillMode: Image.PreserveAspectFit
      cache: false
      source: shellRoot.clipDragImage !== null ? "file://" + shellRoot.clipDragImage.path : ""
      opacity: visible ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 120 } }

      Drag.dragType: Drag.Automatic
      Drag.active: shellRoot.clipDragNative
      Drag.supportedActions: Qt.CopyAction
      Drag.proposedAction: Qt.CopyAction
      // center the drag icon on the cursor instead of its top-left corner
      Drag.hotSpot: Qt.point(90, 65)
      Drag.imageSource: shellRoot.clipDragIcon
      Drag.mimeData: {
        "text/uri-list": shellRoot.clipDragUrl
      }
      Drag.onDragFinished: (dropAction) => {
        shellRoot.clipDragResult = dropAction
        shellRoot.finishClipDrag(dropAction)
      }

      Component.onCompleted: shellRoot.dragGhost = clipDragGhost
      Component.onDestruction: if (shellRoot.dragGhost === clipDragGhost) shellRoot.dragGhost = null
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
      property real t: Config.showShadows ? 1 : 0
      Behavior on t { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
      opacity: box.opacity * t
      visible: box.visible && opacity > 0

      Rectangle {
        id: pillShadowSource
        x: pillShadow.pad
        y: pillShadow.pad + pillShadow.drop
        width: pillShadow.visW
        height: pillShadow.height - pillShadow.pad * 2.2 - pillShadow.drop
        radius: box.radius * box.dpi
        color: Theme.shadowPill

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
        || dashboard
        || cliphistOpen
        || spotlight
        || wallpaperSwitcherOpen
        || powerMenu
        || themePicker
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
      property bool dashboard: false
      property bool controlCenter: false
      property bool wifiPanelOpen: false
      // the panel is a Loader (see wifiPanelHost): built on first open, kept
      // alive just long enough for the close fade to render
      property bool wifiPanelLoaded: false
      onWifiPanelOpenChanged: {
        if (wifiPanelOpen) {
          wifiPanelLoaded = true
          wifiPanelUnloadTimer.stop()
        } else {
          wifiPanelUnloadTimer.restart()
        }
      }

      Timer {
        id: wifiPanelUnloadTimer
        // the panel's own reveal-out is 460ms
        interval: 520
        onTriggered: box.wifiPanelLoaded = false
      }
      property bool bluetoothPanelOpen: false
      // the panel is a Loader (see bluetoothPanelHost): built on first open,
      // kept alive just long enough for the close fade to render
      property bool bluetoothPanelLoaded: false
      onBluetoothPanelOpenChanged: {
        if (bluetoothPanelOpen) {
          bluetoothPanelLoaded = true
          bluetoothPanelUnloadTimer.stop()
        } else {
          bluetoothPanelUnloadTimer.restart()
        }
      }

      Timer {
        id: bluetoothPanelUnloadTimer
        // the panel's own reveal-out is 460ms
        interval: 520
        onTriggered: box.bluetoothPanelLoaded = false
      }
      property bool cliphistOpen: false
      property bool wallpaperSwitcherOpen: false
      property bool cliphistPreviewing: false
      property bool powerMenu: false
      property bool themePicker: false
      property string powerMenuInitialAction: ""

      // the state is unloaded on close, so it never gets to emit previewToggled(false)
      // on its way out; reset here or the pill keeps the full preview shape
      onCliphistOpenChanged: if (!cliphistOpen) cliphistPreviewing = false

      property var battery: UPower.displayDevice
      property bool hasBattery: battery.isLaptopBattery && battery.isPresent
      property bool charging: hasBattery && battery.state === UPowerDeviceState.Charging
      readonly property string batteryIconColor: box.charging || box.batteryLevel > 30 ? Theme.ok : box.batteryLevel <= 15 ? Theme.danger : Theme.warnMed
      readonly property int batteryLevel: hasBattery ? Math.round(battery.percentage * 100) : 0
      // battery icon on laptops, plug icon on desktops
      readonly property string batteryIcon: {
        if (!hasBattery)
          return String.fromCodePoint(0xf06a5) + " " // nf-md-power_plug
        const icons = [0xf0083, 0xf007a, 0xf007d, 0xf007c, 0xf007d, 0xf007e, 0xf007f, 0xf0082, 0xf0081, 0xf0079]
        const base = String.fromCodePoint(icons[Math.min(Math.floor(batteryLevel / 10), 9)])
        return charging ? base + String.fromCodePoint(0xf140b) : base
      }

      onControlCenterChanged: {
        if (!controlCenter) { wifiPanelOpen = false; bluetoothPanelOpen = false }
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

      // cc width, and the wider box the wifi/bluetooth panel takes over
      readonly property real ccBaseWidth: 390
      readonly property real wifiPanelBoxWidth: 340
      readonly property real wifiPanelHeight: 350
      readonly property real bluetoothPanelBoxWidth: 340
      readonly property real bluetoothPanelHeight: 350

      readonly property real baseWidth: activeOsd === "battery" ? osdWidth
                     : activeOsd === "timer" ? osdWidth
                     : activeOsd === "volume" ? osdWidth
                     : activeOsd === "brightness" ? osdWidth
                     : (notificationModule.active && !notifFullscreenMode) ? 320
                     : powerMenu ? 350
                     : controlCenter ? (wifiPanelOpen ? wifiPanelBoxWidth : bluetoothPanelOpen ? bluetoothPanelBoxWidth : ccBaseWidth)
                     : spotlight ? 328
                     : dashboard ? (dashboardLoader.item ? dashboardLoader.item.implicitWidth + 14 : 546)
                     : themePicker ? 310
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
                  : wifiPanelOpen ? wifiPanelHeight
                  : bluetoothPanelOpen ? bluetoothPanelHeight
                  : controlCenter
                      ? Math.max((mprisModule.hasPlayer ? 240 : 118) + notifBump)
                  : (cliphistOpen && cliphistPreviewing) ? 380
                  : themePicker ? 320
                  : dashboard ? (dashboardLoader.item ? dashboardLoader.item.implicitHeight + 16 : 480)
                  : spotlight
                      ? (spotlightLoader.item ? spotlightLoader.item.height + 15 : 250)
                  : wallpaperSwitcherOpen ? 308
                  : cliphistOpen ? 276
                  : mediaPopupShown ? 94
                  : (row.implicitHeight * Config.pillScale) + 10

      readonly property real baseRadius: notificationModule.active ? 99
        : cliphistOpen && cliphistPreviewing ? 33
        : cliphistOpen ? 28
        : wifiPanelOpen ? 25
        : bluetoothPanelOpen ? 25
        : controlCenter ? (notificationModule.notifications.length > 0
          ? (mprisModule.hasPlayer ? 27 : 25)
          : (mprisModule.hasPlayer ? 26 : 22))
        : spotlight ? 29
        : dashboard ? 24
        : themePicker ? 26
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

      color: wifiPanelOpen || bluetoothPanelOpen ? Theme.bgD : bg

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
            if (mouse.button === Qt.LeftButton) {
                box.controlCenter = false
                box.wifiPanelOpen = false
            }
            return
          }

          // same, cliphist accept middle
          if (box.cliphistOpen) {
            if (mouse.button === Qt.MiddleButton) {
              box.cliphistOpen = false
            }
            return
          }

          // dashboard accept only right
          if (box.dashboard) {
            if (mouse.button === Qt.RightButton) {
              box.dashboard = false
            }
            return
          }

          if (box.wallpaperSwitcherOpen) {
            if (mouse.button !== Qt.LeftButton) {
              return
            }
          }

          // theme picker is modal: clicking the pill area closes it
          // (theme cards handle their own click and apply + close)
          if (box.themePicker) {
            box.themePicker = false
            return
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
              console.log("Right click detected, opening dashboard")
              mediaAutoOpened = false
              box.spotlight = false
              box.wallpaperSwitcherOpen = false
              box.powerMenu = false
              box.powerMenuInitialAction = ""
              box.dashboard = !box.dashboard
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
          iconColor: box.volumeModule && box.volumeModule.muted ? box.volumeModule.mutedColor : Theme.fg
          percent: box.volumeModule ? Math.min(box.volumeModule.intendedVol / Config.maxVolume, 1.0) : 0
          muted: box.volumeModule ? box.volumeModule.muted : false
          barWidth: box.volumeModule && box.volumeModule.mutedColor ? 80 : 90
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
        iconColor: Theme.timerFg
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
            onImageDroppedAsWallpaper: (path) => {
              shellRoot.saveCurrentWallpaper(path)
              shellRoot.applyWallpaper(path)
              box.cliphistOpen = false
            }
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
                 && !box.dashboard
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
          width: box.implicitWidth - 14
          // height follows spotlight (shrinks with results)
          height: spotlightLoader.item ? spotlightLoader.item.height : 388
          opacity: box.spotlight
                   && !notificationModule.active
                   && box.activeOsd === ""
                   && !box.controlCenter
                   && !box.dashboard
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
                   && !box.dashboard
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
                   && !box.dashboard
                   && !box.spotlight
                   && !box.wallpaperSwitcherOpen
                   && !box.powerMenu
                   && !box.themePicker
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
        opacity: box.controlCenter && box.activeOsd === "" && !notificationModule.active && !box.powerMenu && !box.wifiPanelOpen && !box.bluetoothPanelOpen ? 1 : 0
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

      // wifi panel, takes over the cc content inside the box
      Item {
        id: wifiPanelHost
        anchors.centerIn: parent
        width: Math.max(0, box.width - 35)
        height: box.wifiPanelOpen ? Math.max(0, box.height - 25) : 0
        opacity: box.wifiPanelOpen
                 && !notificationModule.active
                 && box.activeOsd === "" ? 1 : 0
        // not "opacity > 0": an invisible item cannot take focus, and the panel
        // needs it for the escape/arrow/enter handlers
        visible: box.wifiPanelOpen
        clip: true

        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutExpo } }

        Loader {
          id: wifiPanelLoader
          anchors.fill: parent
          active: box.wifiPanelLoaded
          asynchronous: true

          sourceComponent: Component {
            WifiPanel {
              id: wifiPanel
              anchors.fill: parent
              shown: box.wifiPanelOpen
              onCloseRequested: box.wifiPanelOpen = false
            }
          }
        }
      }

      // bluetooth panel, takes over the cc content inside the box
      Item {
        id: bluetoothPanelHost
        anchors.centerIn: parent
        width: Math.max(0, box.width - 35)
        height: box.bluetoothPanelOpen ? Math.max(0, box.height - 25) : 0
        opacity: box.bluetoothPanelOpen
                 && !notificationModule.active
                 && box.activeOsd === "" ? 1 : 0
        // not "opacity > 0": an invisible item cannot take focus, and the panel
        // needs it for the escape/arrow/enter handlers
        visible: box.bluetoothPanelOpen
        clip: true

        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutExpo } }

        Loader {
          id: bluetoothPanelLoader
          anchors.fill: parent
          active: box.bluetoothPanelLoaded
          asynchronous: true

          sourceComponent: Component {
            BluetoothPanel {
              id: bluetoothPanel
              anchors.fill: parent
              shown: box.bluetoothPanelOpen
              onCloseRequested: box.bluetoothPanelOpen = false
            }
          }
        }
      }

      // dashboard opens on right click
      Item {
        anchors.centerIn: parent
        width: box.implicitWidth - 14
        height: box.dashboard ? box.implicitHeight - 14 : 0  // don't fight the animation
        opacity: box.dashboard
                 && !notificationModule.active
                 && box.activeOsd === ""
                 && !box.cliphistOpen
                 && !box.powerMenu ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
          SequentialAnimation {
            PauseAnimation { duration: box.dashboard ? 1 : 0 }
            NumberAnimation { duration: 300; easing.type: Easing.OutExpo }
          }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton)
                    box.dashboard = !box.dashboard
            }
        }

        // only exists while the dashboard is open
        Loader {
          id: dashboardLoader
          anchors.fill: parent
          active: box.dashboard
          asynchronous: true

          sourceComponent: Dashboard {}
        }
      }

      // theme picker pill state
      Item {
        id: themePickerItem
        anchors.centerIn: parent
        width: box.implicitWidth - 30
        height: box.themePicker ? box.implicitHeight - 30 : 0
        opacity: box.themePicker
                 && !notificationModule.active
                 && box.activeOsd === "" ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
          SequentialAnimation {
            PauseAnimation { duration: box.themePicker ? 1 : 0 }
            NumberAnimation { duration: 300; easing.type: Easing.OutExpo }
          }
        }

        Loader {
          id: themePickerLoader
          anchors.fill: parent
          active: box.themePicker
          asynchronous: true
          sourceComponent: ThemePicker {}
        }

        Connections {
          target: themePickerLoader.item
          function onCloseRequested() { box.themePicker = false }
          function onApplyRequested(name) { Theme.applyTheme(name); box.themePicker = false }
        }
      }
      SystemClock {
        id: clock
        precision: SystemClock.Minutes
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
            box.wifiPanelOpen = false
            box.bluetoothPanelOpen = false
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
        color: fsVolume.volModule && fsVolume.volModule.muted ? fsVolume.volModule.mutedColor : Theme.fg
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
          color: fsVolume.volModule && fsVolume.volModule.muted ? fsVolume.volModule.mutedColor : Theme.fg
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
