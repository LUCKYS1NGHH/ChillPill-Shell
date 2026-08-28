import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

RowLayout {
  id: root
  spacing: 4 * Config.paddingScale

  property string iconFg: "#48cc47"
  property string disconIconFg: "#9ea9bd"

  property string vpnName: ""
  property string pendingVpnName: ""
  readonly property bool connected: vpnName.length > 0

  property string publicIp: ""
  property string country: ""
  property string region: ""
  property var responseLines: []

  property real connectedSince: 0

  // detct vpn via nmcli monitor, event driven so no polling
  function checkVpn() {
    pendingVpnName = ""
    vpnCheck.running = false
    vpnCheck.running = true
  }

  Process {
    id: vpnCheck
    command: ["bash", "-c",
      "nmcli -t -f TYPE,NAME con show --active | awk -F: '$1==\"vpn\"||$1==\"wireguard\"{print $2; exit}'"]
    stdout: SplitParser {
      onRead: data => root.pendingVpnName = data.trim()
    }
    onExited: {
      if (root.pendingVpnName !== root.vpnName) {
        root.vpnName = root.pendingVpnName
        root.connectedSince = Date.now()
      }
    }
  }

  Process {
    running: true
    command: ["nmcli", "monitor"]
    stdout: SplitParser {
      onRead: root.checkVpn()
    }
  }

  Component.onCompleted: checkVpn()

  onVpnNameChanged: {
    if (connected) {
      connectedSince = Date.now()
      ipDelay.restart()
    } else {
      connectedSince = 0
      publicIp = ""
      country = ""
      region = ""
    }
  }

  // give routing a moment to settle before checking the public ip
  Timer {
    id: ipDelay
    interval: 1500
    onTriggered: root.fetchIpInfo()
  }

  // single request of ip + country together with status code handling
  function fetchIpInfo() {
    responseLines = []
    ipInfoCheck.command = ["bash", "-c",
      "curl -s -w '\\n%{http_code}' --max-time 3 'https://ipinfo.io/json'"]
    ipInfoCheck.running = true
  }

  Process {
    id: ipInfoCheck
    stdout: SplitParser {
      onRead: data => root.responseLines.push(data.trim())
    }
    onExited: {
      if (root.responseLines.length === 0) return
      const statusCode = root.responseLines[root.responseLines.length - 1]
      const body = root.responseLines.slice(0, -1).join("")
      if (statusCode === "429") {
        root.country = "Rate limited"
        return
      }
      if (statusCode !== "200") {
        root.country = "Unknown"
        return
      }
      try {
        const info = JSON.parse(body)
        root.publicIp = info.ip ?? ""
        root.country = info.country ?? "Unknown"
        root.region = info.region ?? ""
      } catch (e) {
        root.country = "Unknown"
      }
    }
  }

  // computed lazily only on tooltip hover, dosent tick in the background
  function formattedUptime() {
    if (connectedSince === 0) return ""
    const secs = Math.floor((Date.now() - connectedSince) / 1000)
    const h = Math.floor(secs / 3600)
    const m = Math.floor((secs % 3600) / 60)
    const s = secs % 60
    return h > 0 ? h + "h " + m + "m" : (m > 0 ? m + "m " + s + "s" : s + "s")
  }

  Text {
    text: String.fromCodePoint(root.connected ? 0xf099d : 0xf099e) // nf-md-shield_lock, verify against your icon set
    color: root.connected ? root.iconFg : root.disconIconFg
    font {
      family: Theme.nerdFontFamily
      pixelSize: 10 * Config.pillScale
    }
  }

  Text {
    text: {
      if (!root.connected) return "off"
      if (!Config.showSensitiveInfo) return "on"
      if (root.country.length > 0) return root.country
      return ".."
    }
    color: Theme.fg
    font { family: Theme.fontFamily; pixelSize: 10 * Config.pillScale; weight: 500 }
    elide: Text.ElideRight
    Layout.maximumWidth: 90 * Config.pillScale
  }
}
