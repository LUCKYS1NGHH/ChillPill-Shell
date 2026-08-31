import Quickshell
import QtQuick

Row {
  id: row
  anchors.centerIn: parent
  spacing: 13 * Config.pillScale
  opacity: !box.cliphistOpen
           && !notificationModule.active
           && !mediaAutoOpened
           && !box.controlCenter
           && !box.miniDashboard
           && box.activeOsd === ""
           && !box.wallpaperSwitcherOpen
           && !box.appLauncher ? 1 : 0
  visible: opacity > 0

  Behavior on opacity { NumberAnimation { duration: 100 } }

  // single hover source for the whole row, gaps included
  // for eating hover-able gaps between modules which expands the bar
  // width while hovering or sliding the cursor between bar's modules
  HoverHandler {
    id: rowHover
    target: row
    onHoveredChanged: box.hovered = hovered
  }

  Repeater {
    model: Config.pillModules
    delegate: Item {
      id: wrapper
      anchors.verticalCenter: parent.verticalCenter
      implicitWidth: moduleLoader.implicitWidth
      implicitHeight: moduleLoader.implicitHeight

      Loader {
        id: moduleLoader
        anchors.fill: parent
        source: capitalize(modelData) + ".qml"
        onLoaded: {
          switch (modelData) {
            case "volume":
              box.volumeModule = item
              item.volumeChanged.connect(function() {
                if (!box.controlCenter) box.activeOsd = "volume"
                osdHideTimer.interval = Config.osdDuration
                osdHideTimer.restart()
              })
              break
            case "network":   box.networkModule = item; break
            case "bluetooth": box.bluetoothModule = item; break
            case "clock":     box.clockModule = item; break
            case "vpn":       box.vpnModule = item; break
          }
        }
      }

      // per-module hover: ONLY drives tooltip targeting now, not bar width
      HoverHandler {
        id: hoverHandler
        cursorShape: modelData === "workspaces" ? Qt.PointingHandCursor : Qt.ArrowCursor
        onHoveredChanged: {
          if (hovered) {
            box.tooltipModule = modelData
            if (tooltipPopup.content === "") {
              box.tooltipVisible = false
              return
            }
            var xPos = wrapper.mapToGlobal(wrapper.width / 2, 0).x
            var yPos = row.mapToGlobal(0, row.height).y
            box.tooltipX = xPos
            box.tooltipY = yPos
            box.tooltipVisible = true
          } else {
            box.tooltipVisible = false
          }
        }
      }
    }
  }
}
