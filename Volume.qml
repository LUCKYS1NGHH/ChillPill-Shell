import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

RowLayout {
  id: root
  signal volumeChanged  // signal to bubble up

  onVolChanged: {
    root.volumeChanged()
  }

  property string fg: Theme.fg
  property string mutedFg: "#fd2222"

  property var sink: Pipewire.defaultAudioSink

  readonly property bool ready: sink && sink.ready
  readonly property bool muted: ready && sink.audio.muted
  readonly property int vol: ready ? Math.round(sink.audio.volume * 100) : 0

  property string icon: {
    if (!ready || muted) return String.fromCodePoint(0xf0581)

    if (vol === 0) return String.fromCodePoint(0xf0581)
    if (vol < 40) return String.fromCodePoint(0xf0580)
    if (vol > 70) return String.fromCodePoint(0xf057e)

    return String.fromCodePoint(0xf057e)
  }

  // icon
  Text {
    text: root.icon

    color: {
      if (root.muted || vol === 0) {
        console.log("audio volume status:", root.muted)
        return root.mutedFg
      }
      return root.fg
    }

    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 10
  }

  MouseArea {
    id: audioMuted
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: sink.audio.muted = !sink.audio.muted
    hoverEnabled: true
  }

  // percentage
  Text {
    text: {
      if (!root.ready) return "-"
      if (root.muted) return "0%"

      return root.vol + "%"
    }
    color: fg

    font {
      pixelSize: 10
      family: Theme.fontFamily
      weight: 500
    }
  }

  PwObjectTracker {
    objects: [root.sink]
  }
}
