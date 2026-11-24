import QtQuick
import PillBackend

//  AudioVisualizerModule.qml - pill bar module, enabled with
//  "audioVisualizer" in Config.pillModules.
//
//  cava spawning, parsing and bin slicing now live in C++ (CavaMonitor).
//  QML only draws the bars.

Item {
  id: root

  // no cava binary → the module takes no space in the bar at all.
  readonly property bool available: cava.available

  implicitWidth: available ? viz.implicitWidth : 0
  implicitHeight: available ? viz.implicitHeight : 0

  CavaMonitor {
    id: cava
    active: root.available && root.visible
    barCount: 10
    skipLow: 2   // lowest cava bins are near constant
    skipHigh: 0
    framerate: 60
  }

  AudioVisualizer {
    id: viz
    anchors.centerIn: parent
    visible: root.available

    centered: true
    barCount: cava.barCount
    barWidth: 2 * Config.pillScale
    barSpacing: 1.9 * Config.pillScale
    maxBarHeight: 12 * Config.pillScale
    minBarHeight: 2 * Config.pillScale
    barRadius: 1 * Config.pillScale
    barColor: Theme.fg
    barSecondaryColor: Theme.fg4
    values: cava.values
  }
}
