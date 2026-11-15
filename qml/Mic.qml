import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

RowLayout {
  id: root
  spacing: 4 * Config.paddingScale

  property var source: Pipewire.defaultAudioSource
  readonly property bool ready: source && source.ready
  readonly property bool muted: ready && source.audio.muted
  readonly property int vol: ready ? Math.round(source.audio.volume * 100) : 0

  property string icon: !ready || muted ? String.fromCodePoint(0xf131) // md-microphone_off
    : String.fromCodePoint(0xf130) // md-microphone

  function toggleMute() {
    if (ready) source.audio.muted = !source.audio.muted
  }

  Text {
    text: root.icon
    color: root.muted ? Theme.mutedFg : Theme.fg
    font.family: Theme.nerdFontFamily
    font.pixelSize: 10 * Config.pillScale
  }

  Text {
    text: root.ready ? (root.muted ? "0%" : root.vol + "%") : "-"
    color: Theme.fg
    font { pixelSize: 10 * Config.pillScale; family: Theme.fontFamily; weight: 500 }
  }

  PwObjectTracker { objects: [root.source] }
}
