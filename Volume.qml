import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

RowLayout {
  id: root
  spacing: 6

  property string fg: "#dadada"
  property string mutedFg: "#fd2222"

  property var sink: Pipewire.defaultAudioSink

  readonly property bool ready: sink && sink.ready
  readonly property bool muted: ready && sink.muted
  readonly property int vol: ready ? Math.round(sink.audio.volume * 100) : 0

  readonly property string icon: {
    if (!ready) return String.fromCodePoint(0xf0581)

    if (vol === 0) return String.fromCodePoint(0xf0581)
    if (vol < 35) return String.fromCodePoint(0xf0580)
    if (vol < 70) return String.fromCodePoint(0xf057e)

    return String.fromCodePoint(0xf057e)
  }

  Text {
    text: root.icon

    color: {
    if (root.muted) return root.mutedFg
    return root.fg
    }

    font {
      family: "JetBrainsMono Nerd Font"
      pixelSize: 10
    }
  }

  Text {
    text: {
      if (!root.ready) return "-"
      if (root.muted) return "Muted"

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
