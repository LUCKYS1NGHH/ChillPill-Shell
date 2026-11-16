import QtQuick
import QtQuick.Layouts

Item {
  id: root
  property bool active: false
  property var notif: null
  // what's currently on screen; lags behind `notif` while the swap anim runs
  property var shownNotif: notif

  anchors.centerIn: parent
  opacity: active ? 1 : 0
  visible: opacity > 0
  scale: active ? 1 : 0.94

  RowLayout {
    id: content
    anchors.centerIn: parent
    spacing: 13
    transform: Translate { id: contentSlide; x: 0 }

    // icon chip
    Rectangle {
      Layout.preferredWidth: 30 * box.dpi
      Layout.preferredHeight: 30 * box.dpi
      radius: 20 * box.dpi
      color: Theme.bg2

      Text {
        anchors.centerIn: parent
        text: String.fromCodePoint(0xf0f3)
        color: Theme.fg
        font { family: Theme.nerdFontFamily; pixelSize: 14 }
        visible: notifIcon.status !== Image.Ready
      }

      Image {
        id: notifIcon
        anchors.centerIn: parent
        width: 18 * box.dpi
        height: 18 * box.dpi
        fillMode: Image.PreserveAspectFit
        source: {
          if (root.shownNotif && root.shownNotif.image) return root.shownNotif.image
          if (root.shownNotif && root.shownNotif.appIcon) {
            return root.shownNotif.appIcon.startsWith("/")
              ? "file://" + root.shownNotif.appIcon
              : "image://icon/" + root.shownNotif.appIcon
          }
          return ""
        }
        sourceSize: Qt.size(18 * box.dpi, 18 * box.dpi)
        visible: status === Image.Ready
      }

      // countdown ring around the chip: accent arc unwinds from 12 o'clock
      Canvas {
        id: ringCanvas
        anchors.fill: parent
        anchors.margins: -3 * box.dpi
        antialiasing: true

        onPaint: {
          const ctx = getContext("2d")
          ctx.reset()
          const cx = width / 2, cy = height / 2
          const lw = 2.5 * box.dpi
          const r = parent.width / 2 + lw / 2 // hug the chip's outer edge
          ctx.lineWidth = lw
          ctx.lineCap = "round"
          ctx.strokeStyle = Qt.alpha(Theme.accent, 0.22)
          ctx.beginPath()
          ctx.arc(cx, cy, r, 0, 2 * Math.PI)
          ctx.stroke()
          if (root.timeFrac > 0) {
            ctx.strokeStyle = Theme.accent
            ctx.beginPath()
            ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * root.timeFrac)
            ctx.stroke()
          }
        }
      }
    }

    ColumnLayout {
      spacing: 3
      Text {
        text: root.shownNotif && root.shownNotif.appName ? root.shownNotif.appName : ""
        textFormat: Text.PlainText
        color: Theme.fg3
        font { family: Theme.fontFamily; pixelSize: 8; weight: 600; letterSpacing: 0.5 }
        elide: Text.ElideRight
        Layout.maximumWidth: 220
        visible: text !== "" && Config.showNotifAppName
      }

      Text {
        text: root.shownNotif ? root.shownNotif.summary : ""
        textFormat: Text.PlainText
        color: Theme.fg
        font { family: Theme.fontFamily; pixelSize: 10; weight: 700 }
        elide: Text.ElideRight
        Layout.maximumWidth: 220
      }

      Text {
        text: root.shownNotif ? root.shownNotif.body.replace(
          /\[([^\]]+)\]\(["']?([^)"']+)["']?\)/g,
          '<a href="$2">$1</a>'
        ) : ""
        textFormat: Text.StyledText
        linkColor: Theme.accent
        color: Theme.notificationFg
        font { family: Theme.fontFamily; pixelSize: 9 }
        elide: Text.ElideRight
        Layout.maximumWidth: 220
        visible: text !== ""
      }
    }
  }

  // countdown progress 1→0, drawn as the ring around the icon chip
  property real timeFrac: 1
  onTimeFracChanged: ringCanvas.requestPaint()

  NumberAnimation {
    id: shrink
    target: root
    property: "timeFrac"
    from: 1
    to: 0
    duration: Config.notificationDisplayTime
    easing.type: Easing.Linear
  }

  // queued-notification swap: slide old content out left, swap data, slide new in
  SequentialAnimation {
    id: swapAnim

    ParallelAnimation {
      NumberAnimation { target: content; property: "opacity"; to: 0; duration: 110; easing.type: Easing.InQuad }
      NumberAnimation { target: contentSlide; property: "x"; to: -14; duration: 110; easing.type: Easing.InQuad }
    }

    ScriptAction {
      script: {
        root.shownNotif = root.notif
        contentSlide.x = 14
        root.timeFrac = 1
        shrink.restart()
      }
    }

    ParallelAnimation {
      NumberAnimation { target: content; property: "opacity"; to: 1; duration: 150; easing.type: Easing.OutCubic }
      NumberAnimation { target: contentSlide; property: "x"; to: 0; duration: 150; easing.type: Easing.OutCubic }
    }
  }

  onActiveChanged: {
    if (active) {
      shownNotif = notif
      shrink.restart()
    } else {
      shrink.stop()
      root.timeFrac = 1
      content.opacity = 1
      contentSlide.x = 0
      shownNotif = notif
    }
  }
  onNotifChanged: {
    if (!active) return
    // nothing on screen yet (first activation) or same entry re-shown:
    // plain sync, no swap animation
    if (shownNotif === null || shownNotif === notif) {
      shownNotif = notif
      return
    }
    swapAnim.restart()
  }
}
