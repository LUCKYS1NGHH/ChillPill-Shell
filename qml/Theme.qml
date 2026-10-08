pragma Singleton
import Quickshell
import QtQuick

Singleton {
    // more darker (descending)
    property string bg: "#111111"
    property string bg1: "#141414"
    property string bg2: "#191919"
    property string bg3: "#242424"
    property string bg4: "#292929"
    property string bg5: "#323232"
    property string bg6: "#363636"
    property string bg7: "#404040"
    property string bg8: "#444444"
    property string bg9: "#505050"

    property string bgD: "#0b0b0b"
    property string bgD1: "#121212"

    // more darker (ascending)
    property string fg: "#dadada"
    property string fg1: "#e7e7e7"
    property string fg2: "#dfdfdf"
    property string fg3: "#c4c4c4"
    property string fg4: "#9e9e9e"
    property string fg5: "#777777"
    property string fg6: "#6a6a6a"
    property string fg7: "#484848"
    property string fg8: "#313131"
    property string fgL: "#e9e9e9"

    // CC sliders
    property string sliderBg: "#c9c9c9"

    property string fg3D: "#a7a7a7"
    property string fg4D: "#c5c4c4" // d == darker

    property string borderBg: "#6a6a6a"
    property string borderBg1: "#484848"
    property string borderBg2: "#323232"
    property string borderBg3: "#282828"
    property string borderBg4: "#242424"
    property string borderBgFocus: "#555555"
    property string borderBgFocus1: "#4f4f4f"

    // focus bg
    property string focusBg: "#252525"
    property string focusBg1: "#2e2e2e"
    property string focusBgD: "#222222"
    property string focusBgL: "#353535" // L == lighter

    property string focusFg: "#d1d1d1"
    property string focusFg1: "#bcbcbc"
    property string focusFg2: "#a8a8a8"

    property string fontFamily: Config.textFontFamily
    property string nerdFontFamily: Config.nerdFontFamily

    property string warning: "#fac94a"
    property string deleting: "#e32626"

    property string accent: "#979797"
    property string coverArtGlowShadow: "#80aae6" // hardcored for now

    property int fontSizeBase: 13
    property int fontSize: Math.round(fontSizeBase * Config.pillScale)
}
