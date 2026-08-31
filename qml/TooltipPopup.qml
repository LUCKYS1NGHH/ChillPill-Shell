import Quickshell
import Quickshell.Wayland
import QtQuick
import "./WeatherModule.qml"

PanelWindow {
  id: tooltipWindow
  visible: box.tooltipVisible
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  color: "transparent"

  readonly property real effectiveScale: Config.dpiScale * Config.pillScale

  anchors.top: true
  anchors.left: true
  margins.top: box.tooltipY + effectiveScale * 18
  margins.left: box.tooltipX - implicitWidth / 2

  implicitWidth: label.implicitWidth + 16 * effectiveScale
  implicitHeight: label.implicitHeight + 10 * effectiveScale

  function formatMinutes(seconds) {
    const mins = Math.round(seconds / 60)
    const h = Math.floor(mins / 60)
    const m = mins % 60
    return h > 0 ? h + "h " + m + "m" : m + "m"
  }

  readonly property var tooltipExcluded: ["workspaces"]

  property int refreshTick: 0
  Timer {
    id: refreshTimer
    interval: 1000
    repeat: true
    running: box.tooltipVisible && box.tooltipModule === "vpn"
    onTriggered: tooltipWindow.refreshTick++
  }

  property string content: {
    if (tooltipExcluded.includes(box.tooltipModule)) return ""
    if (refreshTick < 0) return "" // force dependency on refreshTick so content re-evaluates
    switch (box.tooltipModule) {
      case "battery": {
        if (!box.hasBattery) return "No battery • Plugged in"
        if (box.charging && box.battery.timeToFull > 0)
          return "Charging • " + box.batteryLevel + "% • " + formatMinutes(box.battery.timeToFull) + " until full"
        if (!box.charging && box.battery.timeToEmpty > 0)
          return box.batteryLevel + "% • " + formatMinutes(box.battery.timeToEmpty) + " remaining"
        return box.batteryLevel + "%"
      }
      case "volume": {
        const m = box.volumeModule
        if (!m || !m.ready) return "No audio sink"
        if (m.muted) return "Muted" + (m.isHeadphone ? " • Headphones" : "")
        return m.vol + "%" + (m.isHeadphone ? " • Headphones" : " • Speakers")
      }
      case "network": {
        const m = box.networkModule
        if (!m) return "No network info"
        if (m.tethered) return "Wired • Connected"
        if (!m.wifiEnabled) return "Wi-Fi off"
        if (!m.active) return "Wi-Fi on • Not connected"
        return m.active.name + " • " + Math.round(m.signal) + "% signal"
      }
      case "weather": {
        const w = WeatherModule.condition, t = WeatherModule.temp, f = WeatherModule.feelsLike,
              l = WeatherModule.loading, e = WeatherModule.errorMessage   // force-read
        if (l) return "Loading weather…"
        if (e !== "") return e
        if (w === "") return "No weather info"
        const unit = Config.weatherUnits === "metric" ? "°C" : "°F"
        return w + " • " + Math.round(t) + unit
             + (Math.round(f) !== Math.round(t) ? " (feels " + Math.round(f) + unit + ")" : "")
             + " • " + Config.weatherLocation
      }
      case "bluetooth": {
        const m = box.bluetoothModule   // force-read
        if (!m) return "No Bluetooth info"
        if (!m.btEnabled && !m.connected) return "Bluetooth off • Not connected"
        if (!m.btEnabled) return "Bluetooth off"
        if (!m.connected) return "Bluetooth on • Not connected"
        return m.connectedName + " • " + Math.round(m.connectedSignal) + "% signal"
      }
      case "clock": {
        const m = box.clockModule   // force-read
        if (!m) return "No date info"
        const d = new Date()
        let s = Qt.formatDate(d, "dddd, MMM d yyyy")
        if (m.todayEvent !== "") s += " • " + m.todayEvent
        return s
      }
      case "vpn": {
        const m = box.vpnModule   // force-read
        if (!m || !m.connected) return "VPN off"
        let s = "Connected"
        if (m.formattedUptime()) s += " • " + m.formattedUptime()
        if (Config.showSensitiveInfo) {
          if (m.country) s += "\nRegion: " + m.region
          if (m.publicIp) s += "\nIP: " + m.publicIp
        }
        return s
      }
      default:
        return ""
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: 8 * effectiveScale
    color: Theme.bg1
    opacity: box.tooltipVisible ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 100 } }

    Text {
      id: label
      anchors.centerIn: parent
      text: tooltipWindow.content
      color: Theme.fg
      font { family: Theme.fontFamily; pixelSize: 10 * effectiveScale; }
    }
  }
}
