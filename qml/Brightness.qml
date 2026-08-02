import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    signal brightnessUpdated()

    property int brightness: 0
    property int maxBrightness: 100
    // backlight device dir name, e.g. "intel_backlight" or "amdgpu_bl1"
    property string backlightDevice: ""
    readonly property real percent: maxBrightness > 0 ? brightness / maxBrightness : 0
    readonly property string icon: {
        if (percent >= 0.75) return String.fromCodePoint(0xf00e0)
        if (percent >= 0.50) return String.fromCodePoint(0xf00df)
        if (percent >= 0.25) return String.fromCodePoint(0xf00de)
        return String.fromCodePoint(0xf00dd) // typo was fromStringPoint
    }

    Process {
        id: getMax
        command: ["brightnessctl", "max"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.maxBrightness = parseInt(this.text.trim())
        }
    }

    Process {
        id: getCurrent
        command: ["brightnessctl", "get"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.brightness = parseInt(this.text.trim())
                root.brightnessUpdated()
            }
        }
    }

    Timer {
        id: brightnessRefresh
        interval: 50
        onTriggered: getCurrent.running = true
    }

    // detect the real backlight device instead of hardcoding one,
    // so the sysfs watcher below works on any machine. Prefer a
    // device with type "raw" (kernel-native backlight) over
    // "platform"/"firmware" ones like acpi_video0, then fall back
    // to the first device found.
    Process {
        id: deviceProbe
        command: ["sh", "-c", `for d in /sys/class/backlight/*; do
            if [ "$(cat "$d/type" 2>/dev/null)" = raw ]; then
                basename "$d"; exit 0
            fi
        done
        ls /sys/class/backlight | head -1`]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.backlightDevice = this.text.trim().split("\n")[0]
        }
    }

    onBacklightDeviceChanged: {
        if (root.backlightDevice !== "") {
            monitor.command = ["inotifywait", "-m", "-e", "close_write",
                               "/sys/class/backlight/" + root.backlightDevice + "/brightness"]
            monitor.running = true
        }
    }

    Process {
        id: monitor
        stdout: SplitParser {
            onRead: (line) => {
                getCurrent.running = false
                brightnessRefresh.start()
            }
        }
    }

    // icon
    Text {
        text: root.icon
        color: Theme.fg
        font { family: Theme.nerdFontFamily; pixelSize: 10 }
    }

    // percentage
    Text {
        text: Math.round(root.percent * 100) + "%"
        color: Theme.fg
        font { family: Theme.fontFamily; pixelSize: 10; weight: 500 }
    }
}


