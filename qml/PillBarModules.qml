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
          if (modelData === "volume") box.volumeModule = item
          if (modelData === "network") box.networkModule = item
          if (modelData === "bluetooth") box.bluetoothModule = item
          if (modelData === "clock") box.clockModule = item
          if (modelData === "vpn") box.vpnModule = item
        }
        Connections {
          target: modelData === "volume" ? moduleLoader.item : null
          function onVolumeChanged() {
            if (!box.controlCenter) box.activeOsd = "volume"
            osdHideTimer.interval = Config.osdDuration
            osdHideTimer.restart()
          }
        }
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton // purely for hover, doesn't eat clicks
        cursorShape: modelData === "workspaces" ? Qt.PointingHandCursor : Qt.ArrowCursor
        propagateComposedEvents: true
        onEntered: {
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
        }
        onExited: box.tooltipVisible = false
      }
    }
  }
}
