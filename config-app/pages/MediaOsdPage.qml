import QtQuick
import "../components"
import ".."

Page {
    NumRow { label: "Media popup duration"; from: 200; to: 30000; step: 100; suffix: "ms"; value: ConfigStore.get("mediaPopupDuration", 2000); onEdited: (v) => ConfigStore.set("mediaPopupDuration", v) }
    NumRow { label: "OSD duration"; hint: "On Screen Display"; from: 100; to: 10000; step: 100; suffix: "ms"; value: ConfigStore.get("osdDuration", 800); onEdited: (v) => ConfigStore.set("osdDuration", v) }
    NumRow { label: "Max volume"; hint: "Above 100 enables software boost"; from: 50; to: 200; step: 5; suffix: "%"; value: ConfigStore.get("maxVolume", 100); onEdited: (v) => ConfigStore.set("maxVolume", v) }
    Heading { text: "TIMER PRESETS (MINUTES)" }
    NumChips { suffix: "m"; value: ConfigStore.get("timerPresets", []); onEdited: (v) => ConfigStore.set("timerPresets", v) }
}