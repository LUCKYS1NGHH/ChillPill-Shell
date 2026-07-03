import Quickshell
import QtQuick
import QtMultimedia

Item {
  id: root
  property var queue: []
  property var current: null
  readonly property bool active: current !== null
  property int displayTime: 3000

  function trigger() {
      if (notifySound.status === SoundEffect.Ready) {
          notifySound.play()
      }
  }

  SoundEffect {
    id: notifySound
    source: "file:///" + Quickshell.env("HOME") + "/.config/quickshell/notification.wav"
    volume: 1
  }

  function enqueue(notif) {
    if (notif.lastGeneration) {
        queue.push(notif)
        if (!current) advance()
        return
    }

    queue.push(notif)
    trigger() // only play sound for new notifications
    if (!current) advance()
  }

  function advance() {
    if (queue.length === 0) { current = null; return }
    current = queue.shift()
    hideTimer.restart()
  }

  Timer {
    id: hideTimer
    interval: root.displayTime
    onTriggered: {
      if (root.current) root.current.tracked = false
      root.advance()
    }
  }
}
