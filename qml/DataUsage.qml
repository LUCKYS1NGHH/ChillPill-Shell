import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root

    property string rx: "..."
    property string tx: "..."
    property var week: []           // per-day totals (down+up), Mon..Sun
    property var weekDetails: []    // per-day {down, up}, Mon..Sun, in `unit`
    property string unit: "MB"
    property real weekMax: week.length > 0 ? Math.max.apply(null, week) : 0
    property string weekLabel: "--"

    function fmtVal(v) {
        if (unit === "GB") return v.toFixed(2) + " GB"
        return v >= 1024 ? (v / 1024).toFixed(2) + " GB"
            : v >= 100 ? Math.round(v) + " MB"
            : v.toFixed(1) + " MB"
    }

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    Process {
        id: bwProc
        command: ["nusgmon", "--today", "--json"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(this.text.trim())
                    let today = data.today || data
                    let unit = data.unit || "MB"
                    let up   = data.total[0].up
                    let down = data.total[0].down
                    root.rx = down.toFixed(1) + " " + unit
                    root.tx = up.toFixed(1) + " " + unit
                } catch (e) {
                    console.log("nusgmon parse error:", e)
                }
            }
        }
    }

    Process {
        id: weekProc
        command: ["nusgmon", "--thisweek", "--json"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text.trim())
                    const days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                    const vals = []
                    const details = []
                    let total = 0
                    for (const day of days) {
                        const e = d[day] || {}
                        const down = e.down !== undefined ? e.down : 0
                        const up = e.up !== undefined ? e.up : 0
                        vals.push(down + up)
                        details.push({ down: down, up: up })
                        total += down + up
                    }
                    root.week = vals
                    root.weekDetails = details
                    const unit = d.unit || "MB"
                    root.unit = unit
                    root.weekLabel = unit === "GB" ? total.toFixed(2) + " GB"
                        : total >= 1024 ? (total / 1024).toFixed(2) + " GB"
                        : total >= 100 ? Math.round(total) + " MB"
                        : total.toFixed(1) + " MB"
                } catch (e) {
                    console.log("nusgmon week parse error:", e)
                }
            }
        }
    }

    Timer {
        id: refresher
        interval: Config.dataUsageRefreshInterval
        running: box.dashboard
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            bwProc.running = false;  bwProc.running = true
            weekProc.running = false; weekProc.running = true
        }
    }

    Column {
        id: col
        spacing: 2

        Text {
            text: "↓ " + root.rx
            color: Theme.fg
            font { family: Theme.fontFamily; pixelSize: 12; weight: 600 }
        }

        Text {
            text: "↑ " + root.tx
            color: Theme.fg
            opacity: 0.6
            font { family: Theme.fontFamily; pixelSize: 11 }
        }
    }
}
