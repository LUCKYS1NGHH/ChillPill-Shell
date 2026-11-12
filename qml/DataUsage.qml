import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root

    property string rx: "..."
    property string tx: "..."
    property var week: []
    property var weekDetails: []
    property real weekMax: week.length > 0 ? Math.max.apply(null, week) : 0
    property string weekLabel: "--"

    property string range: ["year", "thisweek", "today"].indexOf(Config.dataUsageDefaultRange) >= 0 ? Config.dataUsageDefaultRange : "thisweek"
    property string rangeRx: "..."
    property string rangeTx: "..."
    property string rangeTotal: "--"
    property string todayTotal: "--"
    property var weekLabels: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    property var todaySeries: ({ labels: [], vals: [], details: [], mark: -1 })
    property var rangeSeries: ({ labels: [], vals: [], details: [], mark: -1 })

    property var flags: ({})
    property var retried: ({})
    property var yearCache: ({})
    property var yearQueue: []
    property bool yearBusy: false
    property int yearCur: 1

    readonly property int weekToday: (new Date().getDay() + 6) % 7
    readonly property int thisMonth: new Date().getMonth()
    readonly property bool useRange: range === "year"
    readonly property var bars: range === "thisweek" ? week : range === "today" ? todaySeries.vals : rangeSeries.vals
    readonly property var barDetails: range === "thisweek" ? weekDetails : range === "today" ? todaySeries.details : rangeSeries.details
    readonly property var barLabels: range === "thisweek" ? weekLabels : range === "today" ? todaySeries.labels : rangeSeries.labels
    readonly property real barMax: bars.length > 0 ? Math.max.apply(null, bars) : 0
    readonly property int barMark: range === "thisweek" ? weekToday : range === "today" ? todaySeries.mark : rangeSeries.mark
    readonly property string shownRx: useRange ? rangeRx : rx
    readonly property string shownTx: useRange ? rangeTx : tx
    readonly property string summaryText: range === "today" ? todayTotal : useRange ? rangeTotal : weekLabel

    function fmtMB(v) {
        return v >= 1024 ? (v / 1024).toFixed(2) + " GB"
            : v >= 100 ? Math.round(v) + " MB"
            : v >= 1 ? v.toFixed(1) + " MB"
            : Math.round(v * 1024) + " KB"
    }

    function fmtVal(v) { return fmtMB(v) }

    function factor(u) { return u === "GB" ? 1024 : u === "KB" ? 1 / 1024 : 1 }

    function flagFor(key) { return flags[key] || "--gigabyte" }

    function adjustFlag(key, d, f, proc) {
        let m = 0
        for (const k of Object.keys(d)) {
            if (k === "unit") continue
            const list = Array.isArray(d[k]) ? d[k] : [d[k]]
            for (const x of list) {
                if (!x || typeof x !== "object") continue
                m = Math.max(m, (x.down || 0) * f, (x.up || 0) * f)
            }
        }
        const wanted = m > 1024 ? "--gigabyte" : "--kilobyte"
        if (flagFor(key) === wanted || retried[key]) return false
        const nf = Object.assign({}, flags)
        nf[key] = wanted
        flags = nf
        const nr = Object.assign({}, retried)
        nr[key] = true
        retried = nr
        Qt.callLater(() => { proc.running = false; proc.running = true })
        return true
    }

    function parseSeries(d, markNow, f) {
        const out = { labels: [], vals: [], details: [], mark: -1 }
        const keys = Object.keys(d).filter(k => {
            if (k === "unit" || k === "total") return false
            const e = d[k]
            return e && typeof e === "object" && (e.down !== undefined || e.up !== undefined)
        })
        const now = new Date()
        if (keys.length > 0 && keys.every(k => /^\d{1,2}:\d{2}$/.test(k))) {
            for (let h = 0; h < 24; h++) {
                const key = keys.find(k => parseInt(k) === h)
                const e = key ? d[key] : null
                const dn = e && e.down ? e.down * f : 0
                const upv = e && e.up ? e.up * f : 0
                out.labels.push((h < 10 ? "0" : "") + h + ":00")
                out.vals.push(dn + upv)
                out.details.push({ down: dn, up: upv })
            }
            if (markNow) out.mark = now.getHours()
            return out
        }
        for (const k of keys) {
            const e = d[k]
            const dn = (e.down || 0) * f
            const upv = (e.up || 0) * f
            out.labels.push(k)
            out.vals.push(dn + upv)
            out.details.push({ down: dn, up: upv })
            if (markNow && (k === String(now.getDate()) || k === Qt.formatDate(now, "yyyy-MM-dd"))) out.mark = out.labels.length - 1
        }
        return out
    }

    function rebuildYear() {
        if (Object.keys(yearCache).length === 0) return
        const names = ["January", "February", "March", "April", "May", "June",
                       "July", "August", "September", "October", "November", "December"]
        const vals = []
        const details = []
        let sd = 0
        let su = 0
        for (let m = 1; m <= 12; m++) {
            const c = yearCache[m]
            const dn = c ? c.down : 0
            const upv = c ? c.up : 0
            vals.push(dn + upv)
            details.push({ down: dn, up: upv })
            sd += dn
            su += upv
        }
        rangeSeries = { labels: names, vals: vals, details: details, mark: thisMonth }
        rangeRx = fmtMB(sd)
        rangeTx = fmtMB(su)
        rangeTotal = fmtMB(sd + su)
    }

    function nextMonth() {
        if (yearQueue.length === 0) { yearBusy = false; return }
        yearCur = yearQueue[0]
        yearQueue = yearQueue.slice(1)
        Qt.callLater(() => { monthProc.running = false; monthProc.running = true })
    }

    function startYear() {
        if (yearBusy) return
        const q = []
        for (let m = 1; m <= thisMonth + 1; m++)
            if (!yearCache[m] || m === thisMonth + 1) q.push(m)
        yearQueue = q
        yearBusy = true
        nextMonth()
    }

    function refresh() {
        retried = ({})
        bwProc.running = false;  bwProc.running = true
        weekProc.running = false; weekProc.running = true
        if (range === "year") startYear()
    }

    onRangeChanged: {
        rangeRx = "..."
        rangeTx = "..."
        rangeTotal = "--"
        rangeSeries = ({ labels: [], vals: [], details: [], mark: -1 })
        if (range === "year") rebuildYear()
        if (box.dashboard) refresh()
    }

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    Process {
        id: bwProc
        command: ["nusgmon", "--today", root.flagFor("today"), "--json"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text.trim())
                    const f = root.factor(d.unit)
                    const t = d.total[0]
                    const down = t.down * f
                    const up = t.up * f
                    root.rx = root.fmtMB(down)
                    root.tx = root.fmtMB(up)
                    root.todayTotal = root.fmtMB(up + down)
                    root.todaySeries = root.parseSeries(d, true, f)
                    root.adjustFlag("today", d, f, bwProc)
                } catch (e) {
                    console.log("nusgmon parse error:", e)
                }
            }
        }
    }

    Process {
        id: weekProc
        command: ["nusgmon", "--thisweek", root.flagFor("thisweek"), "--json"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text.trim())
                    const f = root.factor(d.unit)
                    const days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                    const vals = []
                    const details = []
                    let total = 0
                    for (const day of days) {
                        const e = d[day] || {}
                        const down = (e.down !== undefined ? e.down : 0) * f
                        const up = (e.up !== undefined ? e.up : 0) * f
                        vals.push(down + up)
                        details.push({ down: down, up: up })
                        total += down + up
                    }
                    root.week = vals
                    root.weekDetails = details
                    root.weekLabel = root.fmtMB(total)
                    root.adjustFlag("thisweek", d, f, weekProc)
                } catch (e) {
                    console.log("nusgmon week parse error:", e)
                }
            }
        }
    }

    Process {
        id: monthProc
        command: ["nusgmon", "--month", String(root.yearCur), root.flagFor("m" + root.yearCur), "--json"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text.trim())
                    const f = root.factor(d.unit)
                    const t = Array.isArray(d.total) ? d.total[0] : d.total
                    let down = 0
                    let up = 0
                    if (t) {
                        down = (t.down || 0) * f
                        up = (t.up || 0) * f
                    } else {
                        for (const k of Object.keys(d)) {
                            if (k === "unit" || k === "total" || !d[k] || typeof d[k] !== "object") continue
                            down += (d[k].down || 0) * f
                            up += (d[k].up || 0) * f
                        }
                    }
                    const c = Object.assign({}, root.yearCache)
                    c[root.yearCur] = { down: down, up: up }
                    root.yearCache = c
                    root.rebuildYear()
                    if (root.adjustFlag("m" + root.yearCur, d, f, monthProc)) return
                } catch (e) {
                    console.log("nusgmon month parse error:", e, this.text)
                }
                root.nextMonth()
            }
        }
    }

    Timer {
        id: refresher
        interval: Config.dataUsageRefreshInterval
        running: box.dashboard
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Column {
        id: col
        spacing: 2

        Text {
            text: "↓ " + root.shownRx
            color: Theme.fg
            font { family: Theme.fontFamily; pixelSize: 12; weight: 600 }
        }

        Text {
            text: "↑ " + root.shownTx
            color: Theme.fg
            opacity: 0.6
            font { family: Theme.fontFamily; pixelSize: 11 }
        }
    }
}
