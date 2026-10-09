import QtQuick
import QtQuick.Effects

// assigned to layer.effect of a surface Rectangle
MultiEffect {
  shadowEnabled: true
  shadowBlur: 0.75
  shadowVerticalOffset: 5 * Config.dpiScale
  shadowColor: "#7a000000"
}
