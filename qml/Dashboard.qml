import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import PillBackend

// Dashboard (no longer mini :|) -- bento layout
//   left  : identity (basic profile), square-cell calendar, disk ring
//   right : battery, weather, network

Item {
  id: root

  implicitWidth: body.implicitWidth + 15
  implicitHeight: body.implicitHeight + 18

  // bandwidth sampling only while the dashboard is open with the toggle on
  Binding {
    target: BandwidthMonitor
    property: "active"
    value: Config.internetSpeedTestInDashboard && box.dashboard
  }

  property string username: Quickshell.env("USER") || "IDK YOU"
  property string hostname: Quickshell.env("HOST") || ""
  property string uptime: ""
  readonly property int avatar: 58
  readonly property int cell: 26          // calendar cells are cell x cell squares

  // kept so existing handlers in shell.qml don't break
  signal toggleCalendar()
  signal toggleWeather()

  // ===== helpers =====

  function greeting() {
    const h = new Date().getHours()
    return h < 5 ? "still up," : h < 12 ? "good morning," : h < 17 ? "good afternoon," : h < 22 ? "good evening," : "late night,"
  }

  function shortUptime(s) {
    return s.trim().replace(/^up\s+/, "")
      .replace(/\s*(\d+)\s+years?/, "$1y").replace(/\s*(\d+)\s+weeks?/, "$1w")
      .replace(/\s*(\d+)\s+days?/, "$1d").replace(/\s*(\d+)\s+hours?/, "$1h")
      .replace(/\s*(\d+)\s+minutes?/, "$1m").replace(/,/g, " ")
  }

  function fmtBytes(b) {
    const g = b / 1073741824
    return g >= 100 ? Math.round(g) + "G" : g >= 1 ? g.toFixed(1) + "G" : Math.round(b / 1048576) + "M"
  }

  function fmtRate(b) {
    if (b >= 1048576) return (b / 1048576).toFixed(1) + " M/s"
    if (b >= 1024) return Math.round(b / 1024) + " K/s"
    return Math.round(b) + " B/s"
  }

  function usageColor(v) { return v > 0.9 ? "#ec4d4d" : v > 0.75 ? "#ecb04d" : Theme.ok }

  // ---- battery (same wording/rules as TooltipPopup.qml) ----
  function formatMinutes(seconds) {
    const mins = Math.round(seconds / 60)
    const h = Math.floor(mins / 60)
    const m = mins % 60
    return h > 0 ? h + "h " + m + "m" : m + "m"
  }

  // at ~0W (battery protection) the estimate jumps to thousands of hours
  function isUsableEstimate(sec) { return sec > 0 && sec <= 24 * 3600 }

  readonly property string batteryTelemetry: {
    if (box.charging && isUsableEstimate(box.battery.timeToFull))
      return "Charging • " + formatMinutes(box.battery.timeToFull) + " until full"
    if (!box.charging && isUsableEstimate(box.battery.timeToEmpty))
      return formatMinutes(box.battery.timeToEmpty) + " remaining"
    return box.charging ? "Plugged in • Charging" : "Plugged in"
  }

  // optional extras, only shown when UPower reports them
  readonly property string batteryExtra: {
    if (!box.hasBattery) return ""
    const b = box.battery
    const parts = []
    if (b.changeRate !== undefined && Math.abs(b.changeRate) >= 0.1) parts.push(Math.abs(b.changeRate).toFixed(1) + " W")
    if (b.healthSupported && b.healthPercentage > 0) parts.push(Math.round(b.healthPercentage) + "% health")
    return parts.join(" • ")
  }
  readonly property color batteryColor: box.batteryIconColor

  // ---- weather tile data ----
  readonly property var weatherToday: WeatherModule.forecast.length > 0 ? WeatherModule.forecast[0] : null

  // ===== calendar state =====

  property int viewYear: new Date().getFullYear()
  property int viewMonth: new Date().getMonth()
  property int selectedDay: -1
  property var holidays: ({})         // "YYYY-M-D" -> name
  property bool fetchFailed: false
  property bool holidaysEnabled: Config.holidaysUsable()
  property string cachePath: holidaysEnabled
    ? `${Quickshell.env("HOME")}/.cache/chillpill-shell/${Config.holidaysCacheName(viewYear)}` : ""

  readonly property var monthNames: ["January","February","March","April","May","June","July","August","September","October","November","December"]
  readonly property var dayNames: ["Su","Mo","Tu","We","Th","Fr","Sa"]
  readonly property int firstDay: new Date(viewYear, viewMonth, 1).getDay()
  readonly property int daysInMonth: new Date(viewYear, viewMonth + 1, 0).getDate()
  readonly property bool viewingCurrent:
    viewYear === new Date().getFullYear() && viewMonth === new Date().getMonth()

  function holidayFor(d) {
    if (d.getFullYear() !== viewYear) return ""
    return holidays[`${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`] || ""
  }
  function shiftMonth(delta) {
    let m = viewMonth + delta, y = viewYear
    while (m < 0) { m += 12; y-- }
    while (m > 11) { m -= 12; y++ }
    selectedDay = -1
    viewMonth = m
    viewYear = y
  }
  function resetView() {
    selectedDay = -1
    viewYear = new Date().getFullYear()
    viewMonth = new Date().getMonth()
  }

  // footer: clicked day shows its event name alone; otherwise the date
  readonly property string footerText: {
    const d = selectedDay !== -1 ? new Date(viewYear, viewMonth, selectedDay) : new Date()
    const name = holidayFor(d)
    if (selectedDay !== -1 && name !== "") return name
    let s = Qt.formatDate(d, "ddd, MMM d")
    if (name !== "") s = name
    else if (fetchFailed && holidaysEnabled) s += " • holidays unavailable"
    return s
  }

  onHolidaysEnabledChanged: {
    if (!holidaysEnabled) { holidays = ({}); fetchFailed = false }
    else { fetchFailed = false; holidaysFile.reload() }
  }
  onCachePathChanged: { fetchFailed = false; if (holidaysEnabled) holidaysFile.reload() }
  Component.onCompleted: if (holidaysEnabled) holidaysFile.reload()

  FileView {
    id: holidaysFile
    path: root.cachePath
    watchChanges: false
    onLoaded: { try { root.holidays = JSON.parse(text()) } catch (e) { root.holidays = ({}) } }
    onLoadFailed: { if (root.holidaysEnabled && !root.fetchFailed) holidayFetcher.running = true }
  }

  function holidayArgs() {
    const a = ["/usr/share/chillpill-shell/scripts/calendar_events.py",
               Config.country.trim(), root.viewYear.toString(), root.cachePath]
    if (Config.holidaysAllCategories) a.push("--all")
    else if (Config.holidaysCategories.trim()) a.push("--categories", Config.holidaysCategories.trim())
    const sub = Config.holidaysSubdiv.trim()
    if (sub) a.push("--subdiv", sub)
    return a
  }

  Process {
    id: holidayFetcher
    command: root.holidayArgs()
    onExited: (code) => {
      if (code === 0) { root.fetchFailed = false; holidaysFile.reload() }
      else root.fetchFailed = true
    }
  }

  // ===== system stats =====

  property real diskTotal: 0
  property real diskUsed: 0
  property real diskFree: 0
  property string diskDev: ""
  property string diskLabel: ""
  property string diskMount: "/"
  readonly property string diskDevShort: diskDev.replace(/^\/dev\//, "")
  readonly property string diskPathLabel: diskDev === "" ? "/"
    : diskDevShort + "  " + diskMount + (diskLabel !== "" ? "  " + diskLabel : "")
  readonly property real diskPct: diskTotal > 0 ? diskUsed / diskTotal : 0

  Process {
    id: diskProc
    command: ["df", "-B1", "--output=used,size,avail", "/"]
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = this.text.trim().split("\n")
        if (lines.length < 2) return
        const p = lines[1].trim().split(/\s+/)
        root.diskUsed = parseFloat(p[0]) || 0
        root.diskTotal = parseFloat(p[1]) || 0
        root.diskFree = parseFloat(p[2]) || 0
      }
    }
  }
  Process {
    id: diskIdProc
    command: ["findmnt", "--json", "-no", "SOURCE,LABEL,TARGET", "/"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const fs = JSON.parse(this.text.trim()).filesystems[0]
          root.diskDev = fs.source || ""
          root.diskLabel = fs.label || ""
          root.diskMount = fs.target || "/"
        } catch (e) { console.log("findmnt parse error:", e) }
      }
    }
  }
  Timer {
    interval: 30000; repeat: true; triggeredOnStart: true
    running: box.dashboard
    onTriggered: {
      diskProc.running = false; diskProc.running = true
      diskIdProc.running = false; diskIdProc.running = true
    }
  }

  // ---- identity ----
  Process {
    id: hostnameProc
    command: ["sh", "-c", "cat /etc/hostname"]
    running: root.hostname === ""
    stdout: StdioCollector {
      onStreamFinished: {
        const name = this.text.trim()
        if (name !== "") root.hostname = name
        hostnameProc.running = false
      }
    }
  }
  Process {
    id: uptimeProc
    command: ["uptime", "-p"]
    stdout: StdioCollector { onStreamFinished: root.uptime = root.shortUptime(this.text) }
  }
  Timer {
    interval: 60000; repeat: true; triggeredOnStart: true
    running: box.dashboard
    onTriggered: { uptimeProc.running = false; uptimeProc.running = true }
  }

  // ==== building blocks =====

  // surface that fades + slides in; `order` staggers the entrance
  component Card: Rectangle {
    id: card
    property int order: 0
    property bool hoverable: false
    property color baseColor: Theme.bg2
    property color hoverColor: Qt.lighter(Theme.bg2, 1.25)

    radius: 14
    color: hoverable && hh.hovered ? hoverColor : baseColor
    opacity: 0
    transform: Translate { id: shift; y: 12 }
    Behavior on color { ColorAnimation { duration: 140 } }
    HoverHandler { id: hh; enabled: card.hoverable }

    SequentialAnimation {
      id: reveal
      PauseAnimation { duration: card.order * 50 }
      ParallelAnimation {
        NumberAnimation { target: card; property: "opacity"; to: 1; duration: 220 }
        NumberAnimation { target: shift; property: "y"; to: 0; duration: 300; easing.type: Easing.OutCubic }
      }
    }
    Component.onCompleted: reveal.start()
  }

  component Caption: Text {
    color: Theme.fg5
    font { family: Theme.fontFamily; pixelSize: 9; weight: 600; letterSpacing: 1 }
  }

  // tile heading: small square glyph chip + caption
  component TileHead: RowLayout {
    property string glyph: ""
    property string label: ""
    property color accent: Theme.todayFg
    spacing: 7
    Rectangle {
      implicitWidth: 20; implicitHeight: 20; radius: 6
      color: Theme.bg
      Text {
        anchors.centerIn: parent
        text: parent.parent.glyph
        color: parent.parent.accent
        font { family: Theme.nerdFontFamily; pixelSize: 11 }
      }
    }
    Caption { text: parent.label }
  }

  component Meter: Rectangle {
    id: m
    property real value: 0
    property color fill: Theme.todayFg
    implicitHeight: 5
    radius: 3
    color: Theme.bg
    Rectangle {
      width: m.width * Math.max(0, Math.min(1, m.value))
      height: m.height
      radius: 3
      color: m.fill
      Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
      Behavior on color { ColorAnimation { duration: 100 } }
    }
  }

  // circular gauge, animates to its value
  component Ring: Item {
    id: r
    property real value: 0
    property color accent: Theme.todayFg
    property real shown: value
    Behavior on shown { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
    onShownChanged: cv.requestPaint()
    onAccentChanged: cv.requestPaint()
    implicitWidth: 48; implicitHeight: 48

    Canvas {
      id: cv
      anchors.fill: parent
      antialiasing: true
      onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        const c = width / 2, lw = Math.max(4, width * 0.13), rad = c - lw / 2
        ctx.lineWidth = lw
        ctx.lineCap = "round"
        ctx.strokeStyle = Theme.bg
        ctx.beginPath(); ctx.arc(c, c, rad, 0, Math.PI * 2); ctx.stroke()
        if (r.shown > 0.005) {
          ctx.strokeStyle = r.accent
          ctx.beginPath()
          ctx.arc(c, c, rad, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.min(1, r.shown))
          ctx.stroke()
        }
      }
    }
    Text {
      anchors.centerIn: parent
      text: Math.round(Math.min(1, r.value) * 100)
      color: Theme.fg
      font { family: Theme.fontFamily; pixelSize: Math.max(10, Math.round(width * 0.28)); weight: 600 }
    }
  }

  component NavButton: Item {
    id: nb
    property string glyph: ""
    signal clicked()
    implicitWidth: 24; implicitHeight: 24
    Text {
      anchors.centerIn: parent
      text: nb.glyph
      color: na.pressed ? Theme.fg : Theme.fg6
      Behavior on color { ColorAnimation { duration: 100 } }
      font { family: "Symbols Nerd Font"; pixelSize: 11 }
      scale: na.pressed ? 0.85 : 1.0
      Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
    }
    MouseArea {
      id: na
      anchors.fill: parent
      anchors.margins: -8
      cursorShape: Qt.PointingHandCursor
      onClicked: nb.clicked()
    }
  }

  // ==== layout =====

  RowLayout {
    id: body
    anchors.fill: parent
    anchors.margins: 10
    spacing: 8

    // ---------- left: identity + calendar ----------
    ColumnLayout {
      Layout.preferredWidth: root.cell * 7 + 12 + 16
      Layout.fillHeight: true
      Layout.alignment: Qt.AlignTop
      spacing: 8

      Card {
        id: profileCard
        order: 0
        baseColor: Theme.transparent
        Layout.fillWidth: true
        Layout.preferredHeight: root.avatar + 10

        ClippingRectangle {
          id: avatarClip
          width: root.avatar; height: root.avatar
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          radius: width / 2
          property string imgPath: Config.displayPicture
            ? "file://" + Config.displayPicture.replace("~", Quickshell.env("HOME")) : ""
          color: (imgPath === "" || avatarImg.status !== Image.Ready) ? Theme.bg5 : Theme.transparent
          border.width: 2
          border.color: Theme.bg2
          layer.enabled: true
          layer.smooth: true
          layer.mipmap: true
          layer.textureSize: Qt.size(root.avatar, root.avatar)

          Image {
            id: avatarImg
            anchors.fill: parent
            source: avatarClip.imgPath
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            mipmap: true
            sourceSize: Qt.size(root.avatar, root.avatar)
          }
          Text {
            anchors.centerIn: parent
            visible: avatarImg.status !== Image.Ready
            text: root.username.charAt(0).toUpperCase()
            color: Theme.fg
            font { family: Theme.fontFamily; pixelSize: root.avatar * 0.45; weight: 600 }
          }
        }

        ColumnLayout {
          anchors.left: avatarClip.right
          anchors.leftMargin: 10
          anchors.verticalCenter: parent.verticalCenter
          spacing: 0

          Text {
            text: root.greeting()
            color: Theme.fg5
            font { family: Theme.fontFamily; pixelSize: 11; weight: 400 }
          }
          Text {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 19
            text: root.username
            color: Theme.fg
            font { family: Theme.fontFamily; pixelSize: 17; weight: 600 }
          }
          RowLayout {
            id: profileRow
            spacing: 6
            Rectangle {
              // hide rules: no battery tile (weather takes its row), or the
              // hostname chip wouldn't fit next to the priority uptime chip
              readonly property bool fits: profileCard.width - root.avatar - 18
                  >= upChip.implicitWidth + 6 + implicitWidth
              visible: root.hostname !== "" && box.hasBattery
                  && (root.uptime === "" || fits)
              color: Theme.bg2
              radius: 4
              implicitHeight: 15
              implicitWidth: hostText.implicitWidth + 10
              Text {
                id: hostText
                anchors.centerIn: parent
                text: root.hostname
                color: Theme.fg4
                font { family: Theme.fontFamily; pixelSize: 10; weight: 500 }
              }
            }
            Rectangle {
              id: upChip
              visible: root.uptime !== ""
              color: Theme.bg2
              radius: 4
              implicitHeight: 16
              implicitWidth: upText.implicitWidth + 10
              Text {
                id: upText
                anchors.centerIn: parent
                text: "󰔟 " + root.uptime
                color: Theme.fg4
                font { family: Theme.fontFamily; pixelSize: 10; weight: 400 }
              }
            }
          }
        }
      }

      // ----- calendar: square cells -----
      Card {
        order: 1
        radius: 12
        Layout.fillWidth: true
        Layout.preferredHeight: calCol.implicitHeight + 16

        WheelHandler {
          onWheel: (e) => root.shiftMonth(e.angleDelta.y < 0 ? 1 : -1)
        }

        ColumnLayout {
          id: calCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: 8
          spacing: 4

          // month header
          RowLayout {
            id: headerRow
            Layout.fillWidth: true
            spacing: 5

            Text {
              id: monthLbl
              Layout.leftMargin: 4
              // hug the month name; only elide from the right when it would
              // crowd the year / today chip / nav buttons
              Layout.maximumWidth: Math.max(24,
                headerRow.width - 4 - 48 - 5 * (todayChip.visible ? 4 : 3) - 8
                - yrLbl.implicitWidth
                - (todayChip.visible ? todayChip.implicitWidth : 0))
              elide: Text.ElideRight
              text: root.monthNames[root.viewMonth]
              color: Theme.fg
              font { family: Theme.fontFamily; pixelSize: 13; weight: 600 }
            }
            Text {
              id: yrLbl
              text: root.viewYear
              color: Theme.fg5
              font { family: Theme.fontFamily; pixelSize: 11; weight: 400 }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
              id: todayChip
              visible: !root.viewingCurrent
              implicitWidth: todayLbl.implicitWidth + 8
              implicitHeight: 17
              radius: 6
              color: Theme.todayFg
              scale: todayArea.pressed ? 0.90 : 1
              Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
              Text {
                id: todayLbl
                anchors.centerIn: parent
                text: "today"
                color: Theme.bg
                font { family: Theme.fontFamily; pixelSize: 9; weight: 600 }
              }
              MouseArea {
                id: todayArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.resetView()
              }
            }

            NavButton { glyph: "\uf053"; onClicked: root.shiftMonth(-1) }
            NavButton { glyph: "\uf054"; onClicked: root.shiftMonth(1) }
          }

          // weekday row
          RowLayout {
            Layout.fillWidth: true
            spacing: 2
            Repeater {
              model: root.dayNames
              Text {
                Layout.preferredWidth: root.cell
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: Theme.fg5
                font { family: Theme.fontFamily; pixelSize: 10; weight: 600 }
              }
            }
          }

          // 6 fixed rows of true squares; neighbouring-month days are dimmed
          GridLayout {
            Layout.alignment: Qt.AlignHCenter
            columns: 7
            columnSpacing: 2
            rowSpacing: 2

            Repeater {
              model: 42
              delegate: Rectangle {
                id: cell
                readonly property var cellDate: new Date(root.viewYear, root.viewMonth, index - root.firstDay + 1)
                readonly property int dayNum: cellDate.getDate()
                readonly property bool inMonth: cellDate.getMonth() === root.viewMonth
                readonly property bool isToday: {
                  const t = new Date()
                  return cellDate.getFullYear() === t.getFullYear()
                    && cellDate.getMonth() === t.getMonth()
                    && dayNum === t.getDate()
                }
                readonly property bool isHoliday: inMonth && root.holidayFor(cellDate) !== ""
                readonly property bool isSelected: inMonth && root.selectedDay === dayNum
                readonly property bool weekend: index % 7 === 0 || index % 7 === 6

                Layout.preferredWidth: root.cell
                Layout.preferredHeight: root.cell
                visible: index < root.firstDay + root.daysInMonth  // hide next-month filler, saves a row
                radius: 7
                color: isToday ? Theme.todayFg
                     : isSelected ? Theme.bg5
                     : (cellArea.containsMouse && inMonth) ? Theme.bg3
                     : Theme.transparent
                scale: cellArea.pressed ? 0.9 : 1
                Behavior on color { ColorAnimation { duration: 100 } }
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                Text {
                  anchors.centerIn: parent
                  anchors.verticalCenterOffset: cell.isHoliday ? -2 : 0
                  text: cell.dayNum
                  color: cell.isToday ? Theme.bgD
                       : !cell.inMonth ? Theme.fg5
                       : cell.isHoliday ? Theme.todayFg
                       : cell.weekend ? Theme.fg4 : Theme.fg
                  opacity: cell.inMonth ? 1 : 0.35
                  font { family: Theme.fontFamily; pixelSize: 11; weight: (cell.isToday || cell.isHoliday) ? 600 : 400 }
                }

                // holiday marker
                Rectangle {
                  visible: cell.isHoliday
                  width: 3; height: 3; radius: 3
                  anchors.horizontalCenter: parent.horizontalCenter
                  anchors.bottom: parent.bottom
                  anchors.bottomMargin: 4
                  color: cell.isToday ? Theme.bgD : Theme.todayFg
                }

                MouseArea {
                  id: cellArea
                  anchors.fill: parent
                  hoverEnabled: true
                  enabled: cell.inMonth
                  cursorShape: cell.inMonth ? Qt.PointingHandCursor : Qt.ArrowCursor
                  onClicked: root.selectedDay = (root.selectedDay === cell.dayNum) ? -1 : cell.dayNum
                }
              }
            }
          }

          // inset footer: selected day, or today, plus holiday name
          Rectangle {
            Layout.fillWidth: true
            Layout.rightMargin: 3
            implicitHeight: 22
            radius: 6
            color: Theme.bg
            Text {
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.leftMargin: 8
              anchors.rightMargin: 8
              elide: Text.ElideRight
              text: root.footerText
              color: Theme.fg4
              font { family: Theme.fontFamily; pixelSize: 10; weight: 500 }
            }
          }
        }
      }

      // ----- disk: ring left, values right, meter pinned to the bottom -----
      Card {
        order: 2
        Layout.fillWidth: true
        Layout.preferredHeight: 95

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 10
          anchors.bottomMargin: 9
          spacing: 4

          RowLayout {
            Layout.fillWidth: true
            TileHead { glyph: "\uf0a0"; label: "DISK"; accent: root.usageColor(root.diskPct) }
            Item { Layout.fillWidth: true }
            Rectangle {
              radius: 6
              implicitHeight: 15
              implicitWidth: diskPath.implicitWidth + 10
              color: Theme.bg
              Text {
                id: diskPath
                anchors.centerIn: parent
                text: root.diskPathLabel
                color: Theme.fg4
                font { family: Theme.fontFamily; pixelSize: 9; weight: 500 }
              }

              Behavior on implicitWidth {
                NumberAnimation { duration: 250; easing.type: Easing.cubic }
              }
            }
          }
          Item { Layout.fillHeight: true }

          RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Ring {
              implicitWidth: 35; implicitHeight: 35
              value: root.diskPct
              accent: root.usageColor(value)
            }
            Item { Layout.fillWidth: true }
            ColumnLayout {
              spacing: 0
              Layout.alignment: Qt.AlignVCenter

              Text {
                Layout.alignment: Qt.AlignRight
                elide: Text.ElideRight
                text: root.diskTotal > 0 ? root.fmtBytes(root.diskUsed) : "…"
                color: Theme.fg
                font { family: Theme.fontFamily; pixelSize: 14; weight: 600 }
              }
              Text {
                Layout.alignment: Qt.AlignRight
                elide: Text.ElideRight
                text: root.diskTotal > 0 ? Math.round(root.diskPct * 100) + "% of " + root.fmtBytes(root.diskTotal) : ""
                color: Theme.fg4
                font { family: Theme.fontFamily; pixelSize: 10; weight: 400 }
              }
              Text {
                Layout.alignment: Qt.AlignRight
                elide: Text.ElideRight
                text: root.diskTotal > 0 ? root.fmtBytes(root.diskTotal - root.diskUsed) + " free" : ""
                color: Theme.fg5
                font { family: Theme.fontFamily; pixelSize: 10; weight: 400 }
              }
            }
          }
        }
      }
    }

    // ---------- right: bento tiles ----------
    ColumnLayout {
      Layout.preferredWidth: 270
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: 8

      // battery: header + telemetry chip, big % + status, meter pinned to the bottom
      Card {
        order: 1
        visible: box.hasBattery
        Layout.fillWidth: false
        Layout.preferredWidth: 200
        Layout.preferredHeight: 68
        Layout.alignment: Qt.AlignRight

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 10
          anchors.bottomMargin: 8
          spacing: 3

          RowLayout {
            Layout.fillWidth: true
            spacing: 6
            TileHead { glyph: "\uf240"; label: "BATTERY"; accent: root.batteryColor }
            Item { Layout.fillWidth: true }
            Text {
              text: box.batteryLevel + "%"
              color: root.batteryColor
              font { family: Theme.fontFamily; pixelSize: 11; weight: 500 }
            }
            Rectangle {
              visible: root.batteryExtra !== ""
              radius: 7
              implicitWidth: batChip.implicitWidth + 10
              implicitHeight: 15
              color: Theme.bg
              Text {
                id: batChip
                anchors.centerIn: parent
                text: root.batteryExtra
                color: Theme.fg4
                font { family: Theme.fontFamily; pixelSize: 9; weight: 400 }
              }
            }
          }

          Text {
            Layout.fillWidth: true
            Layout.bottomMargin: 2
            elide: Text.ElideRight
            text: root.batteryTelemetry
            color: Theme.fg4
            font { family: Theme.fontFamily; pixelSize: 9; weight: 400 }
          }

          Meter {
            Layout.fillWidth: true
            value: box.batteryLevel / 100
            fill: root.batteryColor
          }
        }
      }

      // ----- weather: header + temp/condition + aligned stat grid -----
      Card {
        order: 2
        Layout.fillWidth: true
        Layout.preferredHeight: weatherCol.implicitHeight + 25

        ColumnLayout {
          id: weatherCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: 10
          spacing: 4

          RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 20
            spacing: 8

            TileHead {
              Layout.alignment: Qt.AlignVCenter
              glyph: WeatherModule.iconGlyph
              label: "WEATHER"
              accent: WeatherModule.isError ? Theme.warning : WeatherModule.iconColor
            }

            Item { Layout.fillWidth: true }

            RowLayout {
              Layout.alignment: Qt.AlignVCenter
              visible: !WeatherModule.isError
              spacing: 4

              Text {
                text: "\uf124"
                color: Theme.fg2
                font { family: Config.nerdFontFamily; pixelSize: 11 }
              }
              Text {
                elide: Text.ElideRight
                text: Config.weatherLocation
                color: Theme.fg4
                font { family: Theme.fontFamily; pixelSize: 9; weight: 500 }
              }
            }

            Rectangle {
              implicitWidth: 20; implicitHeight: 20; radius: 9
              color: refreshArea.containsMouse ? Theme.bg3 : Theme.bg
              Text {
                id: refreshIcon
                anchors.centerIn: parent
                text: "\uf021"
                color: WeatherModule.loading ? Theme.fg5 : Theme.fg4
                font { family: Theme.nerdFontFamily; pixelSize: 9 }

                RotationAnimation {
                  id: spinAnim
                  target: refreshIcon
                  property: "rotation"
                  from: 0
                  to: 360
                  duration: 700
                  direction: RotationAnimation.Clockwise
                  easing.type: Easing.InOutCubic
                }
              }
              scale: refreshArea.pressed ? 0.92 : (refreshArea.containsMouse ? 1.03 : 1)
              Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
              MouseArea {
                id: refreshArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  WeatherModule.refresh()
                  refreshIcon.rotation = 0
                  spinAnim.restart()
                }
              }
            }
          }

          RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 10
            Layout.topMargin: 7
            spacing: 8

            Text {
              text: WeatherModule.loading ? "--"
                  : WeatherModule.isError ? "!"
                  : Math.round(WeatherModule.temp) + WeatherModule.tempUnit
              color: WeatherModule.isError ? Theme.warning : Theme.fg
              font { family: Theme.fontFamily; pixelSize: 18; weight: 600 }
            }
            Text {
              Layout.fillWidth: true
              elide: Text.ElideRight
              text: WeatherModule.loading ? "checking…"
                  : WeatherModule.isError ? "unavailable"
                  : WeatherModule.condition
              color: Theme.fg5
              font { family: Theme.fontFamily; pixelSize: 12 }
            }
          }

          GridLayout {
            visible: !WeatherModule.loading && !WeatherModule.isError
            columns: 3
            columnSpacing: 13
            rowSpacing: 5
            Layout.fillWidth: true
            Layout.leftMargin: 11
            Layout.topMargin: 12

            Repeater {
              model: [
                { icon: "\ue34e", color: Theme.weatherFeels, label: "feels",
                  value: Math.round(WeatherModule.feelsLike) + "°" },
                { icon: "\ue373", color: Theme.weatherHumidity, label: "humidity",
                  value: WeatherModule.humidity + "%" },
                { icon: "\ue34b", color: Theme.weatherWind, label: "wind" + (WeatherModule.windDir ? " " + WeatherModule.windDir : ""),
                  value: Math.round(WeatherModule.windSpeed) + " " + WeatherModule.speedUnit },
                { icon: "", color: Theme.weatherClear, label: "uv", value: String(WeatherModule.uvIndex) },
                { icon: "\ue34c", color: Theme.weatherSunrise, label: "sunrise", value: WeatherModule.sunrise },
                { icon: "\ue34d", color: Theme.weatherSunset, label: "sunset", value: WeatherModule.sunset }
              ]
              delegate: ColumnLayout {
                spacing: 0
                RowLayout {
                  spacing: 7
                  Text {
                    text: modelData.icon
                    color: modelData.color
                    font { family: Config.nerdFontFamily; pixelSize: 12 }
                  }
                  Text {
                    text: modelData.value
                    color: Theme.fg
                    font { family: Theme.fontFamily; pixelSize: 11; weight: 600 }
                  }
                }
                Text {
                  text: modelData.label
                  color: Theme.fg4
                  font { family: Theme.fontFamily; pixelSize: 9 }
                }
              }
            }
          }
        }
      }
      Card {
        order: 4
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: 90

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 10
          spacing: 6

          RowLayout {
            Layout.fillWidth: true
            spacing: 3

            TileHead { glyph: "\uf1eb"; label: "NETWORK"; accent: Theme.netFg }
            Item { Layout.fillWidth: true }
            Rectangle {
              visible: Config.internetSpeedTestInDashboard && BandwidthMonitor.active
              implicitHeight: 15
              implicitWidth: speedText.implicitWidth + 12
              radius: 6
              color: Theme.bg
              Behavior on implicitWidth { NumberAnimation { duration: 250; easing.type: Easing.cubic } }
              Text {
                id: speedText
                anchors.centerIn: parent
                text: "\uf063 " + root.fmtRate(BandwidthMonitor.downloadSpeed)
                    + "  \uf062 " + root.fmtRate(BandwidthMonitor.uploadSpeed)
                color: Theme.fg4
                font { family: Theme.fontFamily; pixelSize: 9; weight: 600 }
              }
            }
            Rectangle {
              visible: netIp.vpn
              implicitWidth: vpnPill.implicitWidth + 12
              implicitHeight: 15
              radius: 7
              color: Qt.alpha(Theme.vpnOkFg, 0.15)
              Text {
                id: vpnPill
                anchors.centerIn: parent
                text: "VPN"
                color: Theme.vpnOkFg
                font { family: Theme.fontFamily; pixelSize: 8; weight: 600; letterSpacing: 1 }
              }
            }
          }

          RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 6
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            spacing: 10
            IpStatus {
              id: netIp
              Layout.alignment: Qt.AlignVCenter
            }
            Item { Layout.fillWidth: true }
            DataUsage {
              id: usageWeek
              Layout.alignment: Qt.AlignVCenter
            }
          }

          // weekly usage graph: one bar per day, today highlighted; hover a bar
          // for that day's down/up breakdown
          RowLayout {
            id: graphRow
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.bottomMargin: 3
            spacing: 3
            Repeater {
              model: 7
              delegate: Item {
                id: dayBar
                readonly property real val: usageWeek.week.length > index ? usageWeek.week[index] : 0
                readonly property var detail: usageWeek.weekDetails.length > index ? usageWeek.weekDetails[index] : null
                readonly property bool isToday: index === (new Date().getDay() + 6) % 7
                readonly property var dayDate: new Date(Date.now() - ((new Date().getDay() + 6) % 7) * 86400000 + index * 86400000)
                readonly property string dayName: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][index]
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignBottom
                Layout.preferredHeight: 24

                Rectangle {
                  width: parent.width
                  anchors.bottom: parent.bottom
                  height: parent.val > 0
                    ? Math.max(3, Math.min(1, parent.val / Math.max(0.001, usageWeek.weekMax)) * 24)
                    : 2
                  radius: 3
                  color: dayArea.containsMouse ? Theme.fg
                       : parent.isToday ? Theme.todayFg
                       : parent.val > 0 ? Theme.fg4
                       : Theme.bg5
                  Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                  Behavior on color { ColorAnimation { duration: 150 } }
                }

                MouseArea {
                  id: dayArea
                  anchors.fill: parent
                  hoverEnabled: true
                  enabled: parent.val > 0
                  cursorShape: parent.val > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                }

                // per-day tooltip: day/date + down/up/total, clamped to the graph row
                Rectangle {
                  id: tip
                  visible: dayArea.containsMouse && dayBar.detail !== null
                  z: 20
                  width: Math.max(tipCol.width, tipCol.implicitWidth) + 14
                  height: tipCol.implicitHeight + 10
                  x: Math.max(-dayBar.x,
                      Math.min(dayBar.width / 2 - width / 2,
                               graphRow.width - dayBar.x - width))
                  y: -height - 5
                  radius: 6
                  color: Theme.bg
                  border.width: 1
                  border.color: Theme.bg5

                  ColumnLayout {
                    id: tipCol
                    anchors.centerIn: parent
                    spacing: 1

                    Text {
                      text: dayBar.dayName + "  " + dayBar.dayDate.getDate() + "/" + (dayBar.dayDate.getMonth() + 1)
                      color: Theme.fg5
                      font { family: Theme.fontFamily; pixelSize: 8; weight: 600; letterSpacing: 1 }
                    }
                    Text {
                      text: "\uf063 " + usageWeek.fmtVal(dayBar.detail ? dayBar.detail.down : 0)
                      color: Theme.fg
                      font { family: Theme.fontFamily; pixelSize: 9; weight: 600 }
                    }
                    Text {
                      text: "\uf062 " + usageWeek.fmtVal(dayBar.detail ? dayBar.detail.up : 0)
                      color: Theme.fg4
                      font { family: Theme.fontFamily; pixelSize: 9 }
                    }
                    Text {
                      text: "total " + usageWeek.fmtVal(dayBar.val)
                      color: dayBar.isToday ? Theme.todayFg : Theme.fg5
                      font { family: Theme.fontFamily; pixelSize: 8; weight: 600 }
                    }
                  }
                }
              }
            }
          }

          // week summary
          RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            Layout.bottomMargin: 5
            spacing: 6
            Text {
              text: "THIS WEEK"
              color: Theme.fg5
              font { family: Theme.fontFamily; pixelSize: 8; weight: 600; letterSpacing: 1 }
            }
            Item { Layout.fillWidth: true }
            Text {
              text: usageWeek.weekLabel
              color: Theme.fg4
              font { family: Theme.fontFamily; pixelSize: 10; weight: 600 }
            }
          }
        }
      }
    }
  }
}
