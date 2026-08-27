pragma Singleton
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  FileView {
    path: Quickshell.env("HOME") + "/.config/chillpill-shell/config.jsonc"
    watchChanges: true
    onFileChanged: reload()

    // fallback values
    JsonAdapter {
      id: adapter
      property string displayPicture: Quickshell.env("HOME") + "/.pfp.png"
      property string clockFormat: "hh:mm"
      property int pillTopMargin: 9
      property int pillBottomMargin: 26
      property string textFontFamily: "Monocraft"
      property string nerdFontFamily: "JetBrainsMono Nerd Font Propo"
      property list<int> timerPresets: [1, 5, 10, 15, 30]
      property int mediaPopupDuration: 3000
      property int maxWorkspaces: 5
      property int notificationDisplayTime: 3000
      property int maxNotificationsInStack: 20
      property int bandwidthRefreshInterval: 300000
      property string screenLockAppCommand: "hyprlock"
      property int osdDuration: 800
      property string weatherUnits: "metric"
      property string weatherLocation: "Delhi"
      property int weatherRefreshInterval: 3600000
      property bool avoidDuplicateNotifications: true
      property string defaultTerminal: "kitty"
      property real pillScale: 1.0
      property real dpiScale: 1.0
      property string wallpapersDir: Quickshell.env("HOME") + "/Pictures/wallpapers"
      property bool wsCloseOnWallpaperSet: true
      property bool wsAnimation: true
      property bool deleteCliphistImgCache: true
      property string country: "Japan"
      property bool showAudioVisuals: true
      property bool showSensitiveInfo: true
      property list<string> pillModules: ["battery", "volume", "workspaces", "network", "clock"]
    }
  }

  readonly property alias displayPicture: adapter.displayPicture
  readonly property alias clockFormat: adapter.clockFormat
  readonly property alias pillTopMargin: adapter.pillTopMargin
  readonly property alias pillBottomMargin: adapter.pillBottomMargin
  readonly property alias textFontFamily: adapter.textFontFamily
  readonly property alias nerdFontFamily: adapter.nerdFontFamily
  readonly property alias timerPresets: adapter.timerPresets
  readonly property alias mediaPopupDuration: adapter.mediaPopupDuration
  readonly property alias maxWorkspaces: adapter.maxWorkspaces
  readonly property alias notificationDisplayTime: adapter.notificationDisplayTime
  readonly property alias maxNotificationsInStack: adapter.maxNotificationsInStack
  readonly property alias bandwidthRefreshInterval: adapter.bandwidthRefreshInterval
  readonly property alias screenLockAppCommand: adapter.screenLockAppCommand
  readonly property alias osdDuration: adapter.osdDuration
  readonly property alias weatherUnits: adapter.weatherUnits
  readonly property alias weatherLocation: adapter.weatherLocation
  readonly property alias weatherRefreshInterval: adapter.weatherRefreshInterval
  readonly property alias avoidDuplicateNotifications: adapter.avoidDuplicateNotifications
  readonly property alias defaultTerminal: adapter.defaultTerminal
  readonly property alias pillScale: adapter.pillScale
  readonly property alias dpiScale: adapter.dpiScale
  readonly property real paddingScale: 1 + (pillScale - 1) * 0.6  // sub linear, keep padding sane
  readonly property alias wallpapersDir: adapter.wallpapersDir
  readonly property alias wsCloseOnWallpaperSet: adapter.wsCloseOnWallpaperSet
  readonly property alias wsAnimation: adapter.wsAnimation
  readonly property alias deleteCliphistImgCache: adapter.deleteCliphistImgCache
  readonly property alias country: adapter.country
  readonly property alias showAudioVisuals: adapter.showAudioVisuals
  readonly property alias showSensitiveInfo: adapter.showSensitiveInfo
  readonly property alias pillModules: adapter.pillModules
}
