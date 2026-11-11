import QtQuick
import "../components"
import ".."

Page {
    Heading { text: "IDENTITY" }
    TextRow { label: "Display picture"; hint: "Shown in the Dashboard"; value: ConfigStore.get("displayPicture", ""); onEdited: (v) => ConfigStore.set("displayPicture", v) }
    Heading { text: "FONTS" }
    TextRow { label: "Text font"; value: ConfigStore.get("textFontFamily", ""); onEdited: (v) => ConfigStore.set("textFontFamily", v) }
    TextRow { label: "Nerd font"; hint: "Used for icons"; value: ConfigStore.get("nerdFontFamily", ""); onEdited: (v) => ConfigStore.set("nerdFontFamily", v) }
    Heading { text: "SCALE & POSITION" }
    SliderRow { label: "Pill scale"; from: 0.5; to: 2; step: 0.05; value: ConfigStore.get("pillScale", 1); onEdited: (v) => ConfigStore.set("pillScale", v) }
    SliderRow { label: "DPI scale"; from: 0.5; to: 3; step: 0.05; value: ConfigStore.get("dpiScale", 1); onEdited: (v) => ConfigStore.set("dpiScale", v) }
    NumRow { label: "Pill top margin"; to: 200; suffix: "px"; value: ConfigStore.get("pillTopMargin", 9); onEdited: (v) => ConfigStore.set("pillTopMargin", v) }
    NumRow { label: "Pill bottom margin"; to: 200; suffix: "px"; value: ConfigStore.get("pillBottomMargin", 26); onEdited: (v) => ConfigStore.set("pillBottomMargin", v) }
    ToggleRow { label: "Audio visualizer"; hint: "Live spectrum in the Control Center's Media Player";  value: ConfigStore.get("showAudioVisuals", true); onEdited: (v) => ConfigStore.set("showAudioVisuals", v) }
    ToggleRow { label: "Shadows"; hint: "Drop shadows under the Pill Bar, its states, popups and the lockscreen"; value: ConfigStore.get("showShadows", true); onEdited: (v) => ConfigStore.set("showShadows", v) }
    Heading { text: "MEDIA PLAYER" }
    ScopeRow {
      label: "Cover art in background"; hint: "Faded cover art behind the media player card";
      optionKey: "mediaCoverBackground"; legacyKey: "iWantMediaCoverInBackground"; fallback: "control center";
      scopeValues: ["controlCenter", "lockscreen", "both", "none"]
    }
    ScopeRow {
      label: "Marquee text"; hint: "Scroll long track titles and artist names instead of eliding";
      optionKey: "mediaMarqueeText"; legacyKey: "marqueeMediaText"; fallback: "none";
    }
    LockToggleRow { label: "Seek bar (lockscreen)"; hint: "Draggable progress bar in the lockscreen's media card"; optionKey: "mediaSeekBar" }
    LockToggleRow { label: "Time labels (lockscreen)"; hint: "Elapsed / total time in the lockscreen's media card"; optionKey: "mediaTimes" }
    LockToggleRow { label: "Transport controls (lockscreen)"; hint: "Previous / play-pause / next in the lockscreen's media card"; optionKey: "mediaTransport" }
}
