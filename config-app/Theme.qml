pragma Singleton
import Quickshell
import QtQuick

Singleton {
    // more darker (descending)
    readonly property string bg: "#121212"
    readonly property string bg1: "#151515"
    readonly property string bg2: "#181818"
    readonly property string bg3: "#212121"
    readonly property string bg4: "#242424"
    readonly property string bg5: "#292929"
    readonly property string bg6: "#323232"
    readonly property string bg7: "#363636"
    readonly property string bg8: "#414141"
    readonly property string bg9: "#434343"

    readonly property string bgD: "#0f0f0f"
    readonly property string bgD1: "#111111"

    // more darker (ascending)
    readonly property string fg: "#dadada"
    readonly property string fg1: "#e7e7e7"
    readonly property string fg2: "#dfdfdf"
    readonly property string fg3: "#c4c4c4"
    readonly property string fg4: "#9e9e9e"
    readonly property string fg5: "#777777"
    readonly property string fg6: "#6a6a6a"
    readonly property string fg7: "#484848"
    readonly property string fg8: "#313131"
    readonly property string fgL: "#e9e9e9"

    // CC sliders
    readonly property string sliderBg: "#c9c9c9"

    readonly property string fg3D: "#a7a7a7"
    readonly property string fg4D: "#c5c4c4" // d == darker

    readonly property string borderBg: "#6a6a6a"
    readonly property string borderBg1: "#484848"
    readonly property string borderBg2: "#323232"
    readonly property string borderBg3: "#282828"
    readonly property string borderBg4: "#242424"
    readonly property string borderBgFocus: "#555555"
    readonly property string borderBgFocus1: "#4f4f4f"

    // focus bg
    readonly property string focusBg: "#252525"
    readonly property string focusBg1: "#2e2e2e"
    readonly property string focusBgD: "#222222"
    readonly property string focusBgL: "#353535" // L == lighter

    readonly property string focusFg: "#d1d1d1"
    readonly property string focusFg1: "#bcbcbc"
    readonly property string focusFg2: "#a8a8a8"

    // live from config store, with the same fallbacks
    readonly property string fontFamily: ConfigStore.get("textFontFamily", "Monocraft")
    readonly property string nerdFontFamily: ConfigStore.get("nerdFontFamily", "JetBrainsMono Nerd Font Propo")  

    readonly property string warning: "#fac94a"
    readonly property string deleting: "#e32626"
    readonly property string ok: "#3ecf6e"

    readonly property string accent: "#979797"
    readonly property string coverArtGlowShadow: "#80aae6" // hardcored for now

    readonly property int fontSizeBase: 13
    readonly property int fontSize: Math.round(fontSizeBase * Config.pillScale)
}
