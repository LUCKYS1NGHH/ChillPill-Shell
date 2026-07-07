import Quickshell
import QtQuick
import QtMultimedia

Item {
  id: root

  // toast state
  property var queue: []
  property var current: null
  readonly property bool active: current !== null
  property int displayTime: 3000

  property bool dndEnabled: false
  property var notifications: []
  property int maxStored: 20

  SoundEffect {
    id: notifySound
    source: "file:///" + Quickshell.env("HOME") + "/.config/quickshell/notification.wav"
    volume: 1
  }

  function trigger() {
    if (notifySound.status === SoundEffect.Ready) notifySound.play()
  }

  function enqueue(notif) {
    notif.receivedTime = new Date() // add time
    notifications.push(notif)
    if (notifications.length > maxStored) {
      let old = notifications.shift()
      old.tracked = false
    }
    notificationsChanged()

    if (dndEnabled) return   // skip popup and sound

    queue.push(notif)
    trigger()
    if (!current) advance()
  }

  function advance() {
    if (queue.length === 0) { current = null; return }
    current = queue.shift()
    hideTimer.restart()
  }

  function dismiss(notif) {
    const idx = notifications.indexOf(notif)
    if (idx === -1) return
    notifications.splice(idx, 1)
    notif.tracked = false
    notificationsChanged()
  }

  function clearAll() {
    notifications.forEach(n => n.tracked = false)
    notifications = []
    notificationsChanged()
  }

  Timer {
    id: hideTimer
    interval: root.displayTime
    onTriggered: root.advance()
  }
}


