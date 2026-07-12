import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root

    property string rx: "..."
    property string tx: "..."

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

    Timer {
        interval: Config.bandwidthRefreshInterval
        running: box.miniDashboard
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            bwProc.running = false
            bwProc.running = true
        }
    }

    Column {
        id: col
        spacing: 2

        Text {
            text: "↓ " + root.rx
            color: Theme.fg
            font { family: Theme.fontFamily; pixelSize: 10; weight: 600 }
        }

        Text {
            text: "↑ " + root.tx
            color: Theme.fg
            opacity: 0.6
            font { family: Theme.fontFamily; pixelSize: 10 }
        }
    }
}
