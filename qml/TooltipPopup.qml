import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
  id: tooltipWindow
  visible: box.tooltipVisible
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  color: "transparent"

  anchors.top: true
  anchors.left: true
  margins.top: box.tooltipY + Config.dpiScale * 18
  margins.left: box.tooltipX - implicitWidth / 2

  implicitWidth: label.implicitWidth + 16 * Config.dpiScale
  implicitHeight: label.implicitHeight + 10 * Config.dpiScale

  function formatMinutes(seconds) {
    const mins = Math.round(seconds / 60)
    const h = Math.floor(mins / 60)
    const m = mins % 60
    return h > 0 ? h + "h " + m + "m" : m + "m"
  }

  readonly property var tooltipExcluded: ["workspaces"]

  readonly property string content: {
    if (tooltipExcluded.includes(box.tooltipModule)) return ""
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
      default:
        return ""
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: 8 * Config.dpiScale
    color: Theme.bg1
    opacity: box.tooltipVisible ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 100 } }

    Text {
      id: label
      anchors.centerIn: parent
      text: tooltipWindow.content
      color: Theme.fg
      font { family: Theme.fontFamily; pixelSize: 10 * Config.pillScale }
    }
  }
}
