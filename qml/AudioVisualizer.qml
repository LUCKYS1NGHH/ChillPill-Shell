import QtQuick
import PillBackend

//  AudioVisualizer.qml - spectrum bar renderer, shared by the control center's
//  media player and the pill bar's "audioVisualizer" module.
//
//  Drawing, rounding and the height animation now live in C++ (SpectrumBars):
//  one scene-graph node, no Repeater, no per-bar items or Behaviors.
//
//  Two looks, picked with `centered`:
//    false - bars grow up from the bottom edge (media player)
//    true  - bars grow symmetrically out of the middle line (pill bar)
//
//  Feed `values` (0-100 per bar, low -> high frequency). Everything else
//  (barCount, barWidth, barSpacing, maxBarHeight, minBarHeight, barRadius,
//  barColor, barSecondaryColor, centered, animationDuration) is a property of
//  SpectrumBars with the same names and defaults as before.
SpectrumBars {
  barColor: Theme.accent
  // alpha 0 = no secondary color
  barSecondaryColor: Theme.transparent
}
