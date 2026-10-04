import QtQuick
import "../components"
import ".."

Page {
    Heading { text: "WEATHER" }
    TextRow { label: "Location"; hint: "City name for weather"; fieldWidth: 200; value: ConfigStore.get("weatherLocation", ""); onEdited: (v) => ConfigStore.set("weatherLocation", v) }
    ChoiceRow { label: "Units"; options: ["metric", "imperial"]; value: ConfigStore.get("weatherUnits", "metric"); onEdited: (v) => ConfigStore.set("weatherUnits", v) }
    NumRow { label: "Refresh interval"; from: 60000; to: 86400000; step: 60000; divisor: 60000; suffix: "min"; value: ConfigStore.get("weatherRefreshInterval", 3600000); onEdited: (v) => ConfigStore.set("weatherRefreshInterval", v) }
    TextRow { label: "Country"; hint: "ISO 3166-1 alpha-2 (IN) or Country Name (India)"; fieldWidth: 80; value: ConfigStore.get("country", ""); onEdited: (v) => ConfigStore.set("country", v.toUpperCase()) }
    Heading { text: "NETWORK USAGE" }
    NumRow { label: "Data usage refresh"; hint: "Only refreshes while the Mini Dashboard is open"; from: 60000; to: 86400000; step: 60000; divisor: 60000; suffix: "min"; value: ConfigStore.get("dataUsageRefreshInterval", 300000); onEdited: (v) => ConfigStore.set("dataUsageRefreshInterval", v) }
}