import QtQuick
import QtQuick.Layouts
import QtMultimedia

Item {
  id: root

  property int totalSeconds: 0
  property int remainingSeconds: 0
  property bool running: false

  function start(minutes) {
    totalSeconds = minutes * 60
    remainingSeconds = totalSeconds
    running = true
    timerTick.start()
  }

  function pause() { running = false; timerTick.stop() }
  function resume() { if (remainingSeconds > 0) { running = true; timerTick.start() } }
  function reset() { running = false; timerTick.stop(); remainingSeconds = 0; totalSeconds = 0 }

  function formatted() {
    let m = Math.floor(remainingSeconds / 60)
    let s = remainingSeconds % 60
    return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
  }

  SoundEffect {
    id: doneSound
    source: "file:///" + Quickshell.env("HOME") + "/.config/quickshell/notification.wav"
  }

  Timer {
    id: timerTick
    interval: 1000
    repeat: true
    onTriggered: {
      remainingSeconds -= 1
      if (remainingSeconds <= 0) {
        running = false
        stop()
        doneSound.play()
      }
    }
  }
}
