import PillBackend
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    signal brightnessUpdated()

    readonly property int brightness: BrightnessMonitor.brightness
    readonly property int maxBrightness: BrightnessMonitor.maxBrightness
    readonly property string backlightDevice: BrightnessMonitor.device
    readonly property real percent: maxBrightness > 0 ? brightness / maxBrightness : 0
    readonly property string icon: {
        if (percent >= 0.75) return String.fromCodePoint(0xf00e0)
        if (percent >= 0.50) return String.fromCodePoint(0xf00df)
        if (percent >= 0.25) return String.fromCodePoint(0xf00de)
        return String.fromCodePoint(0xf00dd)
    }

    onBrightnessChanged: brightnessUpdated()

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
