import QtQuick

//  AudioVisualPreview.qml - thumbnail of the pill bar's "audioVisualizer"
//  module, used by the config app's pill bar preview in place of a plain icon
//  so the preview shows the shape the bar will actually have.
//
//  It mirrors the real module (qml/AudioVisualizerModule.qml): bars growing
//  symmetrically out of a middle line, alternating light/dark. The spectrum is
//  synthetic on purpose - like every other preview in the config app, which
//  all use sample values via PillBarPreview.sample(). The config app is a
//  separate process and has no access to the shell's live cava values.
//
//  `ps` is the pill scale, so the thumbnail tracks the user's pillScale.

Item {
  id: spec

  // animation phase, 0..2π
  property real phase: 0
  // mirror of ModuleThumb.ps, passed in so this file stays self-contained
  property real ps: 1

  readonly property color barColor: "#dadada"   // Theme.fg
  readonly property color barSecondaryColor: "#777777"   // Theme.fg5

  // proportions track the real module so the preview reads true
  readonly property int bars: 9
  readonly property real barWidth: 1.5 * ps
  readonly property real barSpacing: 1.3 * ps
  readonly property real maxAmp: 6 * ps

  implicitWidth: row.implicitWidth
  implicitHeight: 17.5 * ps

  NumberAnimation on phase {
    from: 0; to: Math.PI * 2; duration: 2600
    loops: Animation.Infinite
    running: spec.visible
  }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: spec.barSpacing

    Repeater {
      model: spec.bars

      delegate: Item {
        id: bar
        required property int index
        width: spec.barWidth
        height: spec.implicitHeight

        // two detuned sines per bar, so the shape keeps changing and never
        // looks like a flat loop
        readonly property real v: Math.max(0.12, Math.min(1,
          0.44 + 0.34 * Math.sin(spec.phase + index * 0.8)
                + 0.2 * Math.sin(spec.phase * 1.9 + index * 2.3)))
        readonly property real amp: spec.maxAmp * v
        // alternating tones, like the real module
        readonly property color col: index % 2 === 0 ? spec.barColor : spec.barSecondaryColor

        // upper half
        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.verticalCenter
          width: spec.barWidth
          height: bar.amp
          radius: width / 2
          color: bar.col
        }
        // lower half (mirrored)
        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.top: parent.verticalCenter
          width: spec.barWidth
          height: bar.amp
          radius: width / 2
          color: bar.col
        }
      }
    }
  }
}
