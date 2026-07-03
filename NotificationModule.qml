import QtQuick

Item {
  id: root
  property var queue: []
  property var current: null
  readonly property bool active: current !== null
  property int displayTime: 3000

  function enqueue(notif) {
    queue.push(notif)
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
