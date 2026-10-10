import QtQuick
import "../components"
import ".."

Page {
    Heading { text: "WEATHER" }
    TextRow { label: "Location"; hint: "City name for weather"; fieldWidth: 200; value: ConfigStore.get("weatherLocation", ""); onEdited: (v) => ConfigStore.set("weatherLocation", v) }
    ChoiceRow { label: "Units"; options: ["metric", "imperial"]; value: ConfigStore.get("weatherUnits", "metric"); onEdited: (v) => ConfigStore.set("weatherUnits", v) }
    NumRow { label: "Refresh interval"; from: 60000; to: 86400000; step: 60000; divisor: 60000; suffix: "min"; value: ConfigStore.get("weatherRefreshInterval", 3600000); onEdited: (v) => ConfigStore.set("weatherRefreshInterval", v) }
    Heading { text: "CALENDAR" }
    TextRow { label: "Country"; hint: "ISO 3166-1 alpha-2 (IN) or Country Name (India), blank disables holidays"; fieldWidth: 80; value: ConfigStore.get("country", ""); onEdited: (v) => ConfigStore.set("country", v.toUpperCase()) }
    ToggleRow { label: "Holidays"; hint: "Show holidays in the clock tooltip and calendar popup"; value: ConfigStore.get("holidaysEnabled", true); onEdited: (v) => ConfigStore.set("holidaysEnabled", v) }
    ToggleRow { label: "All categories"; hint: "Ignore the category filter and include everything the country supports"; value: ConfigStore.get("holidaysAllCategories", false); onEdited: (v) => ConfigStore.set("holidaysAllCategories", v) }
    TextRow { label: "Categories"; hint: "Comma separated, e.g. public,optional. Ignored when All categories is on"; fieldWidth: 160; value: ConfigStore.get("holidaysCategories", "public"); onEdited: (v) => ConfigStore.set("holidaysCategories", v) }
    TextRow { label: "Subdivision"; hint: "State/province code, e.g. MH. Empty means nationwide"; fieldWidth: 80; value: ConfigStore.get("holidaysSubdiv", ""); onEdited: (v) => ConfigStore.set("holidaysSubdiv", v.toUpperCase()) }
    Heading { text: "NETWORK USAGE" }
    NumRow { label: "Data usage refresh"; hint: "Only refreshes while the Mini Dashboard is open"; from: 60000; to: 86400000; step: 60000; divisor: 60000; suffix: "min"; value: ConfigStore.get("dataUsageRefreshInterval", 300000); onEdited: (v) => ConfigStore.set("dataUsageRefreshInterval", v) }
}
