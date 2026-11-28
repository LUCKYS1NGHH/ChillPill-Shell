import QtQuick
import PillBackend

//  AudioVisualizerModule.qml - pill bar module, enabled with
//  "audioVisualizer" in Config.pillModules.
//
//  cava spawning, parsing and bin slicing live in C++ (CavaMonitor), with a
//  single shared instance owned by shell.qml. QML only draws the bars.

Item {
  id: root

  // no cava binary → the module takes no space in the bar at all.
  readonly property bool available: shellRoot.cavaAvailable

  implicitWidth: available ? viz.implicitWidth : 0
  implicitHeight: available ? viz.implicitHeight : 0

  AudioVisualizer {
    id: viz
    anchors.centerIn: parent
    visible: root.available

    centered: true
    barCount: 10
    barWidth: 2 * Config.pillScale
    barSpacing: 1.9 * Config.pillScale
    maxBarHeight: 12 * Config.pillScale
    minBarHeight: 2 * Config.pillScale
    barRadius: 1 * Config.pillScale
    barColor: Theme.fg
    barSecondaryColor: Theme.fg4
    // shared cava bins: drop the two lowest (near constant) bins, take 10
    values: shellRoot.visualizerValues.length >= 12
        ? shellRoot.visualizerValues.slice(2, 12) : []
  }
}
