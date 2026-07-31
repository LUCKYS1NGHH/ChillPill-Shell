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

  property int _idCounter: 0
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

  function makeEntry(notif) {
    const entry = {}
    for (let key in notif) {
      entry[key] = notif[key]
    }
    entry.notif = notif
    entry.baseSummary = notif.summary
    entry.count = 1
    entry.receivedTime = new Date()
    entry.tracked = true
    entry._id = _idCounter++
    return entry
  }

  function findDuplicate(notif) {
    for (let i = 0; i < notifications.length; i++) {
      const e = notifications[i]
      if (e.appName === notif.appName &&
          e.baseSummary === notif.summary &&
          e.body === notif.body) {
        return e
      }
    }
    return null
  }

  function enqueue(notif): void {
      // conditional duplicate check
      if (avoidDuplicateNotifications) {
        const dup = findDuplicate(notif)
        if (dup) {
          dup.count += 1
          dup.summary = dup.baseSummary + " (" + dup.count + ")"
          dup.receivedTime = new Date()

          const idx = notifications.indexOf(dup)
          if (idx !== -1) notifications.splice(idx, 1)
          notifications.push(dup)

          syncReversed()
          notificationsChanged()
          if (!dndEnabled) {
            queue.push(dup)
            trigger()
            if (!current) advance()
          }
          console.log("Duplicate notification incremented:", dup.summary)
          return
        }
      }

    const entry = makeEntry(notif)
    notifications.push(entry)
    if (notifications.length > maxStored) {
      const old = notifications.shift()
      old.tracked = false
    }
    syncReversed()
    notificationsChanged()
    if (dndEnabled) return
    queue.push(entry)
    trigger()
    if (!current) advance()
  }

  function advance(): void {
    if (queue.length === 0) { current = null; return }
    current = queue.shift()
    hideTimer.restart()
  }

  function findEntry(target) {
    for (let i = 0; i < notifications.length; i++) {
      const e = notifications[i]
      if (e === target || e.notif === target || e._id === target)
        return i
    }
    return -1
  }

  function dismiss(target): void {
    const idx = findEntry(target)
    if (idx === -1) return
    const entry = notifications[idx]
    notifications.splice(idx, 1)
    entry.tracked = false
    const qidx = queue.indexOf(entry)
    if (qidx !== -1) queue.splice(qidx, 1)
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
