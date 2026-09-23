import Quickshell
import Quickshell.Io
import QtQuick

//  CustomBarModule.qml - waybar-style custom pill bar module
//
//  Object entries in Config.pillModules are rendered by this template in the
//  pill bar, with the same hover-tooltip behavior as the native modules.
//  (String entries like "battery" keep loading the native modules instead.)
//
//  Supported keys (all optional except `run`):
//
//    run       command to execute                                  required
//    icon      static icon string, referenced as {icon} in format / tooltip
//    format    bar text template - {text} / {tooltip} / {icon}
//              default: {icon} {text} (or just {text} when no icon is set)
//    tooltip   hover tooltip template - {text} / {tooltip} / {icon}
//              default: the output's "tooltip" JSON field
//    every     refresh interval in seconds (0 / omitted = run once at startup)
//    stream    keep the process running and update on every stdout line (bool)
//    click     shell command run on left click
//
//  The command may print plain text (used as {text}) or one JSON object per
//  run / per line: { "text": "...", "tooltip": "...", "icon": "..." }
//  (only "text" is required). A "tooltip" / "icon" from the output overrides
//  the static config keys of the same name.
//
//  A leading '~' in a command is expanded to $HOME.

Item {
  id: root

  property var spec: ({})
  property string moduleID: "" // "customN", assigned by PillBarModules
  property string text: ""
  property string tooltip: ""
  property bool loading: false

  readonly property string renderedLabel: computeLabel()
  readonly property string renderedTooltip: computeTooltip()
  // read by PillBarModules to feed the shared bar tooltip
  readonly property string tooltipText: renderedTooltip

  // keep the shared tooltip live while this module is hovered (streaming
  // modules change their tooltip between lines)
  onTooltipTextChanged: {
    if (moduleID !== "" && box.tooltipModule === moduleID) {
      box.customTooltipText = tooltipText
      if (tooltipText === "") box.tooltipVisible = false
    }
  }

  readonly property bool streaming:
    spec.stream === true || String(spec.stream).toLowerCase() === "true"
  readonly property int intervalMs: (parseInt(spec.every) || 0) * 1000

  // effective icon: set by the script's JSON output ({"icon": "..."}) when
  // present, otherwise the static `icon` key from the config entry
  property string icon: ""

  function iconFromSpec() {
    return spec.icon !== undefined && spec.icon !== null ? String(spec.icon) : ""
  }

  // text handling

  function fillTemplate(template, text, tooltip) {
    if (!template) return ""
    return template
      .split("{text}").join(text)
      .split("{tooltip}").join(tooltip)
      .split("{icon}").join(root.icon)
  }

  function parseOutput(raw) {
    let text = String(raw).trim()
    let tooltip = ""
    let icon = ""
    if (text !== "") {
      try {
        const json = JSON.parse(text)
        if (json !== null && typeof json === "object") {
          if (typeof json.text === "string") text = json.text
          if (typeof json.tooltip === "string") tooltip = json.tooltip
          if (typeof json.icon === "string") icon = json.icon
        }
      } catch (e) { /* plain text output, used as-is */ }
    }
    return { text: text, tooltip: tooltip, icon: icon }
  }

  function applyOutput(raw) {
    const entry = parseOutput(raw)
    root.text = entry.text
    root.tooltip = entry.tooltip
    // dynamic icon from the script wins; otherwise fall back to the static one
    root.icon = entry.icon !== "" ? entry.icon : iconFromSpec()
    root.loading = false
  }

  function computeLabel() {
    if (spec.format !== undefined && spec.format !== null && String(spec.format) !== "")
      return fillTemplate(String(spec.format), text, tooltip)
    // no format: show "icon text", or just the text when no icon is set
    return root.icon !== "" ? fillTemplate("{icon} {text}", text, tooltip) : text
  }

  function computeTooltip() {
    if (spec.tooltip !== undefined && spec.tooltip !== null && String(spec.tooltip) !== "")
      return fillTemplate(String(spec.tooltip), text, tooltip)
    return tooltip
  }

  // command helpers

  function expandHome(cmd) {
    return String(cmd).replace(/^~/, Quickshell.env("HOME"))
  }

  function refresh() {
    if (!spec.run) return
    root.loading = true
    runner.command = ["sh", "-c", expandHome(spec.run)]
    runner.running = false
    runner.running = true
  }

  function runAction(cmd) {
    if (!cmd) return
    actionRunner.command = ["sh", "-c", expandHome(cmd)]
    actionRunner.running = false
    actionRunner.running = true
  }

  // one-shot / interval mode: run to completion and collect full stdout
  Process {
    id: runner
    running: false
    stdout: StdioCollector {
      onStreamFinished: root.applyOutput(this.text)
    }
  }

  Timer {
    id: refreshTimer
    interval: root.intervalMs
    repeat: true
    running: false
    onTriggered: root.refresh()
  }

  // streaming mode: keep running, update on every stdout line, respawn if it dies
  Process {
    id: streamer
    running: false
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: line => {
        if (String(line).trim() !== "") root.applyOutput(line)
      }
    }
    onExited: {
      if (root.streaming) respawnTimer.restart()
    }
  }

  Timer {
    id: respawnTimer
    interval: 1000
    onTriggered: {
      streamer.running = false
      streamer.running = true
    }
  }

  // small executor for click actions
  Process { id: actionRunner; running: false }

  // NOTE: the values below are derived *inline* from `spec` on purpose — inside
  // onSpecChanged (which runs during the property write) dependent readonly
  // bindings such as root.streaming / root.intervalMs can still be stale.
  onSpecChanged: {
    const spec = root.spec || {}
    root.icon = iconFromSpec() // static icon baseline; output may override
    if (!spec.run) {
      refreshTimer.running = false
      runner.running = false
      streamer.running = false
      return
    }

    if (spec.stream === true || String(spec.stream).toLowerCase() === "true") {
      // streaming: keep one long-running process, update per stdout line
      refreshTimer.running = false
      runner.running = false
      streamer.command = ["sh", "-c", expandHome(spec.run)]
      streamer.running = false
      streamer.running = true
    } else {
      // one-shot / interval: run once now, then every `every` seconds
      streamer.running = false
      refreshTimer.interval = (parseInt(spec.every) || 0) * 1000
      refreshTimer.running = refreshTimer.interval > 0
      root.refresh() // waybar-style: no `every` → run once at startup
    }
  }

  implicitWidth: label.implicitWidth
  implicitHeight: label.implicitHeight

  Text {
    id: label
    text: root.renderedLabel
    color: Theme.fg
    font {
      family: Theme.fontFamily
      weight: 500
      pixelSize: 10 * Config.pillScale
      letterSpacing: -0.5
    }
  }

  // input

  TapHandler {
    acceptedButtons: spec.click ? Qt.LeftButton : 0
    onTapped: (eventPoint, button) => {
      if (button === Qt.LeftButton) root.runAction(spec.click)
    }
  }
}
