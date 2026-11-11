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
      property string theme: ""
      property int pillTopMargin: 9
      property int pillBottomMargin: 26
      property string textFontFamily: "Monocraft"
      property string nerdFontFamily: "JetBrainsMono Nerd Font Propo"
      property list<int> timerPresets: [1, 5, 10, 15, 30]
      property int mediaPopupDuration: 3000
      property int maxWorkspaces: 5
      property int notificationDisplayTime: 3000
      property int maxNotificationsInStack: 20
      property int dataUsageRefreshInterval: 300000
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
      property bool holidaysEnabled: true
      property bool holidaysAllCategories: false
      property string holidaysCategories: "public"
      property string holidaysSubdiv: ""
      property bool showAudioVisuals: true
      property bool showSensitiveInfo: true
      property bool showShadows: true
      property bool internetSpeedTestInDashboard: false
      property var pillModules: ["battery", "volume", "workspaces", "network", "clock"]
      property string customWallpaperScript: ""
      property bool pillOnHover: false
      property bool confirmPowerActions: true
      // suspend/restart/shutdown buttons on the lockscreen card
      property bool lockscreenPowerActions: true
      // media player strip on the lockscreen card (hidden when nothing plays)
      property bool lockscreenMedia: true
      // dim the backlight after N idle seconds on the lockscreen (0 = off)
      property int lockscreenIdleDim: 3
      // idle dim target as a percent of the current backlight level
      property int lockscreenIdleDimTo: 25
      property int maxVolume: 100
      property bool separatePreviewTabTypes: true
      property bool appLauncherFuzzySearch: false
      property bool cliphistFuzzySearch: false
      // Spotlight "?" mode template, %s is replaced by the url-encoded query
      property string webSearchUrl: "https://duckduckgo.com/?q=%s"
      // media feature scopes: "both" | "controlCenter" | "lockscreen" | "none"
      property string mediaCoverBackground: ""
      property string mediaMarqueeText: ""
      property string mediaSeekBar: ""
      property string mediaTimes: ""
      property string mediaTransport: ""
      property bool iWantMediaCoverInBackground: false
      property bool marqueeMediaText: false
      property bool iNeedMediaPlayingPopup: true
    }
  }

  readonly property alias displayPicture: adapter.displayPicture
  readonly property alias clockFormat: adapter.clockFormat
  readonly property alias theme: adapter.theme
  readonly property alias pillTopMargin: adapter.pillTopMargin
  readonly property alias pillBottomMargin: adapter.pillBottomMargin
  readonly property alias textFontFamily: adapter.textFontFamily
  readonly property alias nerdFontFamily: adapter.nerdFontFamily
  readonly property alias timerPresets: adapter.timerPresets
  readonly property alias mediaPopupDuration: adapter.mediaPopupDuration
  readonly property alias maxWorkspaces: adapter.maxWorkspaces
  readonly property alias notificationDisplayTime: adapter.notificationDisplayTime
  readonly property alias maxNotificationsInStack: adapter.maxNotificationsInStack
  readonly property alias dataUsageRefreshInterval: adapter.dataUsageRefreshInterval
  readonly property alias screenLockAppCommand: adapter.screenLockAppCommand
  readonly property alias osdDuration: adapter.osdDuration
  readonly property alias weatherUnits: adapter.weatherUnits
  readonly property alias weatherLocation: adapter.weatherLocation
  readonly property alias weatherRefreshInterval: adapter.weatherRefreshInterval
  readonly property alias avoidDuplicateNotifications: adapter.avoidDuplicateNotifications
  readonly property alias defaultTerminal: adapter.defaultTerminal
  readonly property alias pillScale: adapter.pillScale
  readonly property alias dpiScale: adapter.dpiScale
  readonly property alias wallpapersDir: adapter.wallpapersDir
  readonly property alias wsCloseOnWallpaperSet: adapter.wsCloseOnWallpaperSet
  readonly property alias wsAnimation: adapter.wsAnimation
  readonly property alias deleteCliphistImgCache: adapter.deleteCliphistImgCache
  readonly property alias country: adapter.country
  readonly property alias holidaysEnabled: adapter.holidaysEnabled
  readonly property alias holidaysAllCategories: adapter.holidaysAllCategories
  readonly property alias holidaysCategories: adapter.holidaysCategories
  readonly property alias holidaysSubdiv: adapter.holidaysSubdiv
  readonly property alias showAudioVisuals: adapter.showAudioVisuals
  readonly property alias showSensitiveInfo: adapter.showSensitiveInfo
  readonly property alias showShadows: adapter.showShadows
  readonly property alias internetSpeedTestInDashboard: adapter.internetSpeedTestInDashboard
  readonly property alias pillModules: adapter.pillModules
  readonly property alias customWallpaperScript: adapter.customWallpaperScript
  readonly property alias pillOnHover: adapter.pillOnHover
  readonly property alias confirmPowerActions: adapter.confirmPowerActions
  readonly property alias lockscreenPowerActions: adapter.lockscreenPowerActions
  readonly property alias lockscreenMedia: adapter.lockscreenMedia
  readonly property alias lockscreenIdleDim: adapter.lockscreenIdleDim
  readonly property alias lockscreenIdleDimTo: adapter.lockscreenIdleDimTo
  readonly property alias maxVolume: adapter.maxVolume
  readonly property alias separatePreviewTabTypes: adapter.separatePreviewTabTypes
  readonly property alias appLauncherFuzzySearch: adapter.appLauncherFuzzySearch
  readonly property alias cliphistFuzzySearch: adapter.cliphistFuzzySearch
  readonly property alias webSearchUrl: adapter.webSearchUrl
  // empty scope key -> fall back to the legacy boolean (cover/marquee) or "both"
  function mediaScope(key, legacyDefault) {
    const v = adapter[key]
    if (v !== undefined && v !== null && v !== "")
      return v
    return legacyDefault
  }

  readonly property string mediaCoverBackgroundScope: mediaScope("mediaCoverBackground", iWantMediaCoverInBackground ? "both" : "none")
  readonly property string mediaMarqueeTextScope: mediaScope("mediaMarqueeText", marqueeMediaText ? "both" : "none")
  readonly property string mediaSeekBarScope: mediaScope("mediaSeekBar", "both")
  readonly property string mediaTimesScope: mediaScope("mediaTimes", "both")
  readonly property string mediaTransportScope: mediaScope("mediaTransport", "both")

  // host is "controlCenter" or "lockscreen"
  function mediaOn(scope, host) {
    if (scope === "both") return true
    if (scope === "none" || scope === undefined || scope === null || scope === "") return false
    return scope === host
  }

  readonly property alias mediaCoverBackground: adapter.mediaCoverBackground
  readonly property alias mediaMarqueeText: adapter.mediaMarqueeText
  readonly property alias mediaSeekBar: adapter.mediaSeekBar
  readonly property alias mediaTimes: adapter.mediaTimes
  readonly property alias mediaTransport: adapter.mediaTransport
  readonly property alias iWantMediaCoverInBackground: adapter.iWantMediaCoverInBackground
  readonly property alias marqueeMediaText: adapter.marqueeMediaText
  readonly property alias iNeedMediaPlayingPopup: adapter.iNeedMediaPlayingPopup

  // cache file name changes with the flags so stale data never leaks in
  function holidaysCacheSuffix() {
    const cats = holidaysCategories.trim() || "public"
    let s = holidaysAllCategories ? "all" : cats.toLowerCase()
    const sub = holidaysSubdiv.trim().toUpperCase()
    if (sub) s += "_" + sub
    return s.replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "") || "public"
  }

  function holidaysCacheName(year) {
    return `events_${country.trim().toUpperCase()}_${year}_${holidaysCacheSuffix()}.json`
  }

  function holidaysUsable() {
    const c = country.trim().toLowerCase()
    return holidaysEnabled && c !== "" && c !== "none"
  }
}
