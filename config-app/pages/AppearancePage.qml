import QtQuick
import "../components"
import ".."

Page {
    Heading { text: "IDENTITY" }
    TextRow { label: "Display picture"; hint: "Shown in the Mini Dashboard"; value: ConfigStore.get("displayPicture", ""); onEdited: (v) => ConfigStore.set("displayPicture", v) }
    Heading { text: "FONTS" }
    TextRow { label: "Text font"; value: ConfigStore.get("textFontFamily", ""); onEdited: (v) => ConfigStore.set("textFontFamily", v) }
    TextRow { label: "Nerd font"; hint: "Used for icons"; value: ConfigStore.get("nerdFontFamily", ""); onEdited: (v) => ConfigStore.set("nerdFontFamily", v) }
    Heading { text: "SCALE & POSITION" }
    SliderRow { label: "Pill scale"; from: 0.5; to: 2; step: 0.05; value: ConfigStore.get("pillScale", 1); onEdited: (v) => ConfigStore.set("pillScale", v) }
    SliderRow { label: "DPI scale"; from: 0.5; to: 3; step: 0.05; value: ConfigStore.get("dpiScale", 1); onEdited: (v) => ConfigStore.set("dpiScale", v) }
    NumRow { label: "Pill top margin"; to: 200; suffix: "px"; value: ConfigStore.get("pillTopMargin", 9); onEdited: (v) => ConfigStore.set("pillTopMargin", v) }
    NumRow { label: "Pill bottom margin"; to: 200; suffix: "px"; value: ConfigStore.get("pillBottomMargin", 26); onEdited: (v) => ConfigStore.set("pillBottomMargin", v) }
    ToggleRow { label: "Audio visualizer"; hint: "Live spectrum in the Control Center's Media Player";  value: ConfigStore.get("showAudioVisuals", true); onEdited: (v) => ConfigStore.set("showAudioVisuals", v) }
    ToggleRow { label: "Shadows"; hint: "Drop shadows under the Pill Bar and its popups"; value: ConfigStore.get("showShadows", true); onEdited: (v) => ConfigStore.set("showShadows", v) }
    ToggleRow { label: "Media cover in media player's background"; hint: "Faded cover art in Control center's media player of the current media playing"; value: ConfigStore.get("iWantMediaCoverInBackground", false); onEdited: (v) => ConfigStore.set("iWantMediaCoverInBackground", v) }
}
