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
//  run / per line: { "text": "...", "tooltip": "...", "icon": "...", "color": "..." }
//  (only "text" is required). A "tooltip" / "icon" from the output overrides
//  the static config keys of the same name; "color" (output-only) tints the
//  bar's {icon} glyph, falling back to Theme.fg when absent.
//
//  If the JSON output is missing the required "text" field, the bar shows the
//  error message "ERR: missing text" in place of {text} (instead of the raw
//  JSON output). In that error state any surrounding config template text is
//  ignored too — e.g. format "{text} MB" renders only "ERR: missing text" —
//  and the tooltip explains the problem: "I need atleast 'text' in JSON
//  output".
//
//  A leading '~' in a command is expanded to $HOME.

Item {
  id: root

  property var spec: ({})
  property string moduleID: "" // "customN", assigned by PillBarModules
  property string text: ""
  property string tooltip: ""
  property bool loading: false
  // set when the last JSON output had no "text": the bar and tooltip show only
  // the error message, ignoring the config's format / tooltip template (so
  // "{text} MB" doesn't render as "ERR: missing text MB")
  property bool outputError: false

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

  // JSON "color" field (e.g. "#e5c07b"): tints ONLY the bar's {icon}; the rest
  // of the label stays Theme.fg. Empty = fall back to Theme.fg.
  property string color: ""

  readonly property bool showHtml: color !== ""
  readonly property string labelHtml: buildLabelHtml()

  function esc(s) {
    return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
  }

  function templateString() {
    if (spec.format !== undefined && spec.format !== null && String(spec.format) !== "")
      return String(spec.format)
    return root.icon !== "" ? "{icon} {text}" : "{text}"
  }

  // like computeLabel(), but wraps the {icon} glyph in a colored span so the
  // icon picks up the JSON color while the rest keeps Theme.fg. Only engaged
  // when a color was provided (html on), otherwise the plain path is used.
  function buildLabelHtml() {
    if (!showHtml) return renderedLabel
    if (root.outputError) return esc(text)
    const escapedText = esc(text)
    const escapedTooltip = esc(tooltip)
    const span = '<span style="color:' + esc(color) + '">'
      + esc(icon)
      + '</span>'
    return templateString()
      .split("{text}").join(escapedText)
      .split("{tooltip}").join(escapedTooltip)
      .split("{icon}").join(span)
  }

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
    let color = ""
    let outputError = false
    if (text !== "") {
      try {
        const json = JSON.parse(text)
        if (json !== null && typeof json === "object") {
          if (typeof json.text === "string") {
            text = json.text
          } else {
            // required "text" field missing: show an error message in the bar
            // in place of {text} instead of dumping the raw JSON output
            text = "ERR: missing text"
            outputError = true
          }
          if (typeof json.tooltip === "string") tooltip = json.tooltip
          if (typeof json.icon === "string") icon = json.icon
          if (typeof json.color === "string") color = json.color
        }
      } catch (e) { /* plain text output, used as-is */ }
    }
    return { text: text, tooltip: tooltip, icon: icon, color: color, outputError: outputError }
  }

  function applyOutput(raw) {
    const entry = parseOutput(raw)
    root.text = entry.text
    root.tooltip = entry.tooltip
    // dynamic icon from the script wins; otherwise fall back to the static one
    root.icon = entry.icon !== "" ? entry.icon : iconFromSpec()
    // color comes from the output only; empty means Theme.fg for the icon
    root.color = entry.color
    root.outputError = entry.outputError
    root.loading = false
  }

  function computeLabel() {
    // error state: show only the error message — ignore the config's format
    // template (e.g. "{text} MB") so no wrapper text is appended
    if (root.outputError) return text
    return fillTemplate(templateString(), text, tooltip)
  }

  function computeTooltip() {
    // error state: explain what the module needs instead of the config's
    // tooltip template (e.g. "... {tooltip} MB of RAM") and instead of the
    // raw output
    if (root.outputError) return "I need atleast 'text' in JSON output"
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
    root.color = ""            // no static color key; output decides
    root.outputError = false   // fresh module, no stale error state
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
    text: root.showHtml ? root.labelHtml : root.renderedLabel
    textFormat: root.showHtml ? Text.RichText : Text.PlainText
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
