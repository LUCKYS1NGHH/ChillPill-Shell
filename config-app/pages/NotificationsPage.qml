import QtQuick
import "../components"
import ".."

Page {
    Heading { text: "NOTIFICATIONS" }
    NumRow { label: "Display time"; from: 500; to: 60000; step: 500; suffix: "ms"; value: ConfigStore.get("notificationDisplayTime", 3000); onEdited: (v) => ConfigStore.set("notificationDisplayTime", v) }
    NumRow { label: "Max notifications in stack"; from: 1; to: 200; value: ConfigStore.get("maxNotificationsInStack", 20); onEdited: (v) => ConfigStore.set("maxNotificationsInStack", v) }
    ToggleRow { label: "Avoid duplicate notifications"; hint: "Collapse repeats into a counter"; value: ConfigStore.get("avoidDuplicateNotifications", true); onEdited: (v) => ConfigStore.set("avoidDuplicateNotifications", v) }
    Heading { text: "PRIVACY" }
    ToggleRow { label: "Show sensitive info"; hint: "VPN module's information (City, IP Address etc.)"; value: ConfigStore.get("showSensitiveInfo", true); onEdited: (v) => ConfigStore.set("showSensitiveInfo", v) }
}