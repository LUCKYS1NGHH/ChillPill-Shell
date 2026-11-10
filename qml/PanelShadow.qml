import QtQuick
import QtQuick.Effects

// assigned to layer.effect of a surface Rectangle; the drop shadow spreads
// in/out smoothly as Config.showShadows is flipped
MultiEffect {
  id: fx

  property real t: Config.showShadows ? 1 : 0
  Behavior on t { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

  shadowEnabled: true
  shadowBlur: 0.15 + 0.65 * t                    // tight flat -> full spread
  shadowVerticalOffset: 8 * Config.dpiScale * t  // lifts out as it spreads
  shadowColor: Qt.alpha(Theme.shadowSoft, t)
}
