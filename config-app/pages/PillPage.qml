import QtQuick
import "../components"
import ".."

Page {
    Heading { text: "MODULES (LEFT → RIGHT)" }
    ModulesEditor {
        known: ["battery", "volume", "workspaces", "network", "clock", "brightness", "vpn", "notifications", "bluetooth", "weather", "audioVisualizer"]
        value: ConfigStore.cfg.pillModules === undefined ? [] : ConfigStore.cfg.pillModules
        onEdited: (v) => ConfigStore.set("pillModules", v)
    }
    Heading { text: "BEHAVIOUR" }
    ToggleRow { label: "Show pill on hover"; hint: "Auto hide the Pill Bar"; value: ConfigStore.get("pillOnHover", false); onEdited: (v) => ConfigStore.set("pillOnHover", v) }
    TextRow { label: "Clock format"; hint: "Qt format string, e.g. hh:mm or h:mm AP"; fieldWidth: 160; value: ConfigStore.get("clockFormat", "hh:mm"); onEdited: (v) => ConfigStore.set("clockFormat", v) }
    NumRow { label: "Max workspaces"; from: 1; to: 20; value: ConfigStore.get("maxWorkspaces", 5); onEdited: (v) => ConfigStore.set("maxWorkspaces", v) }
}