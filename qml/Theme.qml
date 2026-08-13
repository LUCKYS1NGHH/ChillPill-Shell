pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    FileView {
        id: walColors
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"

        onLoaded: {
            let data = JSON.parse(text())
            root.accent = data.colors.color5
        }
    }

    function reloadColors() { walColors.reload() }

    property string bg: "#171717"
    property string bg1: "#151515"

    property string fg: "#dadada"
    property string fg1: "#e7e7e7"
    property string fg2: "#dfdfdf"
    property string fg3d: "#a7a7a7"
    property string fg4d: "#c5c4c4" // d == darker

    property string fontFamily: Config.textFontFamily
    property string nerdFontFamily: Config.nerdFontFamily
    property string accent: accent
    property string coverArtGlowShadow: accent

    property int fontSizeBase: 13
    property int fontSize: Math.round(fontSizeBase * Config.pillScale)
}
