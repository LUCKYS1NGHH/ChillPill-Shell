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
           && !box.powerMenu
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

      // pillModules entries can be a module name ('clock') or a waybar-style
      // custom module object ({ "run": "...", ... }) handled by CustomBarModule.qml
      readonly property bool isCustom: typeof modelData === "object" && modelData !== null
      readonly property string moduleID: isCustom ? "custom" + index : String(modelData)

      visible: !isCustom || !!modelData.run

      Loader {
        id: moduleLoader
        anchors.fill: parent
        source: isCustom ? "CustomBarModule.qml" : capitalize(modelData) + ".qml"
        onLoaded: {
          if (isCustom) {
            item.spec = modelData
            item.moduleID = moduleID
            return
          }
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
      TapHandler {
        acceptedButtons: Qt.LeftButton
        enabled: !isCustom && (modelData === "volume" || modelData === "network" || modelData === "bluetooth")
        onTapped: {
          if (isCustom) return
          switch (modelData) {
            case "volume":
              if (moduleLoader.item && moduleLoader.item.toggleMute)
                moduleLoader.item.toggleMute()
              break
            case "network":
              if (moduleLoader.item && moduleLoader.item.toggleWifi)
                moduleLoader.item.toggleWifi()
              break
            case "bluetooth":
              if (moduleLoader.item && moduleLoader.item.toggleBluetooth)
                moduleLoader.item.toggleBluetooth()
              break
          }
        }
      }
      HoverHandler {
        id: hoverHandler
        cursorShape: isCustom
          ? (modelData.click
             ? Qt.PointingHandCursor : Qt.ArrowCursor)
          : (modelData === "workspaces" || modelData === "volume"
             || modelData === "network" || modelData === "bluetooth")
            ? Qt.PointingHandCursor : Qt.ArrowCursor
        onHoveredChanged: {
          if (hovered) {
            box.tooltipModule = moduleID
            if (isCustom) {
              // custom modules render their own tooltip (tooltip/{tooltip}); the
              // shared tooltip popup reads it through customTooltipText
              const moduleItem = moduleLoader.item
              box.customTooltipText = moduleItem && typeof moduleItem.tooltipText === "string"
                ? moduleItem.tooltipText : ""
            }
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
            if (isCustom) box.customTooltipText = ""
          }
        }
      }
    }
  }
}
