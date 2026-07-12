import Quickshell
import QtQuick
import QtMultimedia

Item {
  id: root

  // toast state
  property var queue: []
  property var current: null
  readonly property bool active: current !== null
  property int displayTime: Config.notificationDisplayTime

  property bool dndEnabled: false
  property var notifications: []
  property var notificationsReversed: [] // pre-computed. avoid recomputing per bindig
  property int maxStored: Config.maxNotificationsInStack
  property bool avoidDuplicateNotifications: Config.avoidDuplicateNotifications

  SoundEffect {
    id: notifySound
    source: "file:///" + Quickshell.env("HOME") + "/.config/quickshell/notification.wav"
    volume: 1
  }

  function trigger(): void {
    if (notifySound.status === SoundEffect.Ready) notifySound.play()
  }

  function syncReversed(): void {
    notificationsReversed = notifications.slice().reverse()
  }

  function isDuplicate(notif): bool {
    for (let i = 0; i < notifications.length; i++) {
      const n = notifications[i]
      if (n.appName === notif.appName &&
          n.summary === notif.summary &&
          n.body === notif.body) {
        return true
      }
    }
    return false
  }

  function enqueue(notif): void {
    // conditionl duplicate check
    if (avoidDuplicateNotifications && isDuplicate(notif)) {
      console.log("Duplicate notification ignored:", notif.summary)
      return
    }

    notif.receivedTime = new Date()
    notif.tracked = true
    notifications.push(notif)
    if (notifications.length > maxStored) {
      const old = notifications.shift()
      old.tracked = false
    }
    syncReversed()
    notificationsChanged()

    if (dndEnabled) return

    queue.push(notif)
    trigger()
    if (!current) advance()
  }

  function advance(): void {
    if (queue.length === 0) { current = null; return }
    current = queue.shift()
    hideTimer.restart()
  }

  function dismiss(notif): void {
    const idx = notifications.indexOf(notif)
    if (idx === -1) return
    notifications.splice(idx, 1)
    notif.tracked = false
    syncReversed()
    notificationsChanged()
  }

  function clearAll(): void {
    for (let i = 0; i < notifications.length; i++) notifications[i].tracked = false
    notifications = []
    notificationsReversed = []
    notificationsChanged()
  }

  Timer {
    id: hideTimer
    interval: root.displayTime
    onTriggered: root.advance()
  }
}
