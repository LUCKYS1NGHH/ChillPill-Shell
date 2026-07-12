import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    signal brightnessUpdated()

    property int brightness: 0
    property int maxBrightness: 100
    readonly property real percent: maxBrightness > 0 ? brightness / maxBrightness : 0
    readonly property string icon: {
        if (percent >= 0.75) return String.fromCodePoint(0xf00e0)
        if (percent >= 0.50) return String.fromCodePoint(0xf00df)
        if (percent >= 0.25) return String.fromCodePoint(0xf00de)
        return String.fromStringPoint(0xf00dd)
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

    Process {
        id: monitor
        command: ["inotifywait", "-m", "-e", "close_write", "/sys/class/backlight/intel_backlight/brightness"]
        running: true
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


