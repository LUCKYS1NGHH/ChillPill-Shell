import QtQuick

//  AudioVisualizerModule.qml - pill bar module, enabled with
//  "audioVisualizer" in Config.pillModules (see PillBarModules.qml for the
//  id -> file mapping).
//
//  Same live spectrum as the control center's media player, but drawn in the
//  pill's flavour: the bars are mirrored around their middle line (a wave
//  instead of a bottom-anchored skyline).

Item {
  id: root

  // no spectrum process → the module takes no space in the bar at all.
  // Note this is deliberately independent of Config.showAudioVisuals: that
  // toggle only controls the control center's media player, adding or removing
  // the module here is what turns this one on.
  readonly property bool available: shellRoot.cavaAvailable

  implicitWidth: available ? viz.implicitWidth : 0
  implicitHeight: available ? viz.implicitHeight : 0

  AudioVisualizer {
    id: viz
    anchors.centerIn: parent
    visible: root.available

    // mirrored look: the wave grows out of the center, not the bottom
    centered: true
    barCount: 10
    barWidth: 2 * Config.pillScale
    barSpacing: 1.9 * Config.pillScale
    maxBarHeight: 12 * Config.pillScale
    // thin line while silent, so an idle bar still reads as a module
    minBarHeight: 2 * Config.pillScale
    barRadius: 1 * Config.pillScale
    barColor: Theme.fg
    // two-tone so the mirrored bars read as a wave instead of a solid block
    barSecondaryColor: Theme.fg4
    // skip the (near constant) lowest and highest cava bins
    values: shellRoot.visualizerValues ? shellRoot.visualizerValues.slice(2, 2 + barCount) : []
  }
}
