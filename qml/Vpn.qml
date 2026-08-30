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
  readonly property bool connected: vpnName.length > 0
  property string publicIp: ""
  property string country: ""
  property string region: ""
  property real connectedSince: 0
  property int vpnCheckGen: 0
  property bool _ready: false
  property int ipFetchAttempts: 0
  property bool _needsVerify: true

  // gate nmcli monitor events till startup setlles so initial check isnt killed as stale
  Timer {
    id: startupGate
    interval: 800
    running: true
    onTriggered: root._ready = true
  }

  // detect vpn via nmcli monitor event driven so no polling
  function checkVpn() {
    vpnCheckGen++
    vpnCheck.running = false
    vpnCheck.running = true
  }

  Process {
    id: vpnCheck
    property int gen: 0
    command: ["bash", "-c",
      "nmcli -t -f TYPE,NAME con show --active | awk -F: '$1==\"vpn\"||$1==\"wireguard\"{print $2; exit}'"]
    stdout: StdioCollector {
      onStreamFinished: {
        if (vpnCheck.gen !== root.vpnCheckGen) return
        const name = text.trim()
        // splitparser race: using stdiocollector gives full output before onexited so we dont rely on async onread
        if (name !== root.vpnName) {
          root.vpnName = name
          // connectedsince also set in onvpnnamechanged set here too so uptime is correct even if handler races
          root.connectedSince = name.length > 0 ? Date.now() : 0
        } else if (name.length > 0 && root.connectedSince === 0) {
          // reload case where vpnname was already correct but connectedsince was reset
          root.connectedSince = Date.now()
          // ensure ip fetch still happens if country is empty eg first check was considered stale
          if (root.country.length === 0) ipDelay.restart()
        }
        console.log("vpnCheck done gen", vpnCheck.gen, "name:", JSON.stringify(name), "vpnName:", JSON.stringify(root.vpnName), "connected:", root.connected)
      }
    }
    onRunningChanged: if (running) gen = root.vpnCheckGen
  }

  Timer {
    id: checkVpnDebounce
    interval: 150
    onTriggered: root.checkVpn()
  }

  Process {
    running: true
    command: ["nmcli", "monitor"]
    stdout: SplitParser {
      onRead: {
        if (!root._ready) return
        checkVpnDebounce.restart()
      }
    }
  }

  Component.onCompleted: checkVpn()

  // fallback if we are connected but country is still empty after startup retry once
  // covers case where first check was discarded as stale due to monitor burst
  Timer {
    id: startupRetry
    interval: 2200
    running: true
    onTriggered: {
      if (root.connected && root.country.length === 0 && !ipInfoCheck.running) {
        console.log("startupRetry: connected but country empty refetching")
        root.fetchIpInfo()
      }
      // also reverify vpnname in case initial nmcli was transient empty
      if (!root.connected) root.checkVpn()
    }
  }

  onVpnNameChanged: {
    // do not use connected here: qml binding for connected may not have reevaluated
    // yet when this handler fires so it can still be false even though vpnname is non empty
    // that caused ip fetch to never trigger on launch reload country stays empty
    const isConnected = vpnName.length > 0
    console.log("vpnName ->", JSON.stringify(vpnName), "connected:", isConnected, "(root.connected:", connected, ")")
    if (isConnected) {
      connectedSince = Date.now()
      ipFetchAttempts = 0
      _needsVerify = true
      ipDelay.restart()
      ipRetry.stop()
    } else {
      connectedSince = 0
      publicIp = ""
      country = ""
      region = ""
      ipFetchAttempts = 0
      _needsVerify = false
      ipDelay.stop()
      ipRetry.stop()
      routeCheck.running = false
      ipInfoCheck.running = false
    }
  }

  // give routing a moment to setlle before checking public ip
  // 32s is enough for most tunnels wg openvpn to finish handshake and route injection
  // previously 15s fetched too early and returned isp ip instead of vpn ip
  Timer {
    id: ipDelay
    interval: 3200
    onTriggered: {
      console.log("ipDelay fired calling fetchIpInfo connected:", root.connected, "vpnName:", root.vpnName)
      if (root.vpnName.length > 0) root.fetchIpInfo()
    }
  }

  // verfiy fetch to overwrite early isp result runs once after first successful fetch
  Timer {
    id: ipRetry
    interval: 3500
    repeat: false
    onTriggered: {
      if (root.vpnName.length > 0) {
        console.log("ipRetry verify fetch")
        // reset route attempts for this verify run
        root.ipFetchAttempts = 0
        root.fetchIpInfo()
      }
    }
  }

  // gate: ensure tunnel route exists before hitting ipinfo else we would cache isp ip
  Process {
    id: routeCheck
    // checks both egress dev for 1111 and existence of tunnel interfaces
    command: ["bash", "-c", "echo \"---route---\"; ip route get 1.1.1.1 2>/dev/null; echo \"---link---\"; ip link show 2>/dev/null | grep -E 'tun|wg|ppp|proton|mullvad' || true"]
    stdout: StdioCollector {
      onStreamFinished: {
        console.log("routeCheck raw:", text)
        if (root.vpnName.length === 0) return
        const hasTunnel = text.includes("tun") || text.includes("wg") || text.includes("ppp") || text.includes("proton") || text.includes("mullvad")
        // route line like 1111 via dev tun0 if dev is tun wg we are good
        const routeDevMatch = text.match(/dev\s+(\S+)/)
        const routeDev = routeDevMatch ? routeDevMatch[1] : ""
        const routeIsVpn = routeDev.startsWith("tun") || routeDev.startsWith("wg") || routeDev.includes("ppp") || routeDev.includes("proton") || routeDev.includes("mullvad")
        console.log("routeCheck hasTunnel:", hasTunnel, "routeDev:", routeDev, "routeIsVpn:", routeIsVpn)

        if (hasTunnel && routeIsVpn) {
          // routing is via vpn safe to query ipinfo
          ipInfoCheck.running = false
          ipInfoCheck.running = true
        } else if (hasTunnel && !routeIsVpn) {
          // tunnel exists but route not yet switched wait and retry
          if (root.ipFetchAttempts < 4) {
            root.ipFetchAttempts++
            console.log("routeCheck: tunnel exists but route still via", routeDev, "retrying in 2s")
            retryRouteTimer.restart()
          } else {
            console.log("routeCheck: max retries querying ipinfo anyway")
            ipInfoCheck.running = false
            ipInfoCheck.running = true
          }
        } else {
          // no tunnel interface at all could be splittunnel or nm hasnt created it yet
          if (root.ipFetchAttempts < 3) {
            root.ipFetchAttempts++
            console.log("routeCheck: no tunnel interface yet retrying")
            retryRouteTimer.restart()
          } else {
            console.log("routeCheck: no tunnel after retries querying ipinfo anyway")
            ipInfoCheck.running = false
            ipInfoCheck.running = true
          }
        }
      }
    }
  }

  Timer {
    id: retryRouteTimer
    interval: 2000
    onTriggered: root.fetchIpInfo()
  }

  // single request of ip and country together with status code handling
  function fetchIpInfo() {
    console.log("fetchIpInfo attempt", ipFetchAttempts, "vpn:", vpnName)
    if (root.vpnName.length === 0) return
    // verify routing first if check is already running its completion will trigger curl
    if (routeCheck.running) {
      console.log("fetchIpInfo: routeCheck already running will retry after")
      return
    }
    routeCheck.running = false
    routeCheck.running = true
  }

  Process {
    id: ipInfoCheck
    command: ["bash", "-c",
      "curl -s -w '\\n%{http_code}' --max-time 5 'https://ipinfo.io/json'"]
    stdout: StdioCollector {
      onStreamFinished: {
        console.log("ipInfoCheck raw:", text)
        // if vpn disconnected while we were fetching ignore result
        if (root.vpnName.length === 0) {
          console.log("ipInfoCheck: vpn disconnected while fetching ignoring")
          return
        }
        const lines = text.trim().split("\n")
        if (lines.length === 0) return
        const statusCode = lines[lines.length - 1]
        const body = lines.slice(0, -1).join("")
        if (statusCode === "429") { root.country = "Rate limited"; return }
        if (statusCode !== "200") { root.country = "Unknown"; return }
        try {
          const info = JSON.parse(body)
          const newIp = info.ip ?? ""
          const newCountry = info.country ?? "Unknown"
          const newRegion = info.region ?? ""
          // only overwrite if we actually got a country schedule verify fetch
          // to replace a possible early isp result with real vpn result
          const isFirst = root.country === "" && newCountry !== ""
          root.publicIp = newIp
          root.country = newCountry
          root.region = newRegion
          console.log("ipInfoCheck parsed ip:", newIp, "country:", newCountry, "first:", isFirst)
          if (isFirst && root._needsVerify) {
            root._needsVerify = false
            console.log("ipInfoCheck: scheduling verify fetch to confirm vpn routing")
            ipRetry.restart()
          }
        } catch (e) { root.country = "Unknown" }
      }
    }
  }

  // computed lazily only on tooltip hover dont tick in background
  function formattedUptime() {
    if (connectedSince === 0) return ""
    const secs = Math.floor((Date.now() - connectedSince) / 1000)
    const h = Math.floor(secs / 3600)
    const m = Math.floor((secs % 3600) / 60)
    const s = secs % 60
    return h > 0 ? h + "h " + m + "m" : (m > 0 ? m + "m " + s + "s" : s + "s")
  }

  Text {
    text: String.fromCodePoint(root.connected ? 0xf099d : 0xf099e) // shield lock icon
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
