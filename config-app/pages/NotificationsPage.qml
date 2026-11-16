import QtQuick
import "../components"
import ".."

Page {
    Heading { text: "NOTIFICATIONS" }
    NumRow { label: "Display time"; from: 500; to: 60000; step: 500; suffix: "ms"; value: ConfigStore.get("notificationDisplayTime", 3000); onEdited: (v) => ConfigStore.set("notificationDisplayTime", v) }
    NumRow { label: "Max notifications in stack"; from: 1; to: 200; value: ConfigStore.get("maxNotificationsInStack", 20); onEdited: (v) => ConfigStore.set("maxNotificationsInStack", v) }
    ToggleRow { label: "Avoid duplicate notifications"; hint: "Duplicate notifications repeats into a counter"; value: ConfigStore.get("avoidDuplicateNotifications", true); onEdited: (v) => ConfigStore.set("avoidDuplicateNotifications", v) }
    ToggleRow { label: "App name in popup"; hint: "Sender name above the summary in the notification popup"; value: ConfigStore.get("showNotifAppName", true); onEdited: (v) => ConfigStore.set("showNotifAppName", v) }
}
