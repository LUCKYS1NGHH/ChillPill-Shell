import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root

    property string ip: "..."
    property string iface: "..."
    property bool vpn: false

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    // detect ip with interface
    Process {
        id: ipProc
        command: ["sh", "-c", "ip route get 1.1.1.1 | awk '{print $7; print $5}'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n")
                root.ip    = lines[0] || "unknown"
                root.iface = lines[1] || "unknown"
            }
        }
    }

    // detect vpn via tun/wg interfaces
    Process {
        id: vpnProc
        command: ["sh", "-c", "ip link show | grep -qE 'tun[0-9]|wg[0-9]|proton' && echo yes || echo no"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.vpn = this.text.trim() === "yes"
        }
    }

    // refresh every minute
    Timer {
        interval: 60000
        running: box.miniDashboard
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            ipProc.running = false; ipProc.running = true
            vpnProc.running = false; vpnProc.running = true
        }
    }

    Column {
        id: col
        spacing: 2

        Row {
            spacing: 5

            Text {
                text: root.vpn ? "󰦝" : "󰩟"
                color: root.vpn ? "#64d667" : "#6496dd"
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
            }

            Text {
                text: root.ip
                color: Theme.fg
                font { family: Theme.fontFamily; pixelSize: 10; weight: 600 }
            }
        }

        Text {
            text: root.iface + (root.vpn ? "  VPN" : "")
            color: Theme.fg
            opacity: 0.5
            font { family: Theme.fontFamily; pixelSize: 8 }
        }
    }
}
