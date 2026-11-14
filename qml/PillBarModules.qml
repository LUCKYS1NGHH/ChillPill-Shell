import Quickshell
import Quickshell.Services.SystemTray
import QtQuick

Row {
  id: row
  anchors.centerIn: parent
  spacing: 13 * Config.pillScale
  opacity: !box.cliphistOpen
           && !notificationModule.active
           && !mediaAutoOpened
           && !box.controlCenter
           && !box.dashboard
           && !box.powerMenu
           && box.activeOsd === ""
           && !box.wallpaperSwitcherOpen
           && !box.themePicker
           && !box.spotlight ? 1 : 0
  visible: opacity > 0

  Behavior on opacity { NumberAnimation { duration: 100 } }

  // pillModules entries are normally loaded as Capitalize(name).qml, these are
  // the few that need a different file (the audio visualizer module is named
  // after the component it wraps, AudioVisualizer.qml)
  readonly property var moduleFiles: ({
    "audioVisualizer": "AudioVisualizerModule.qml"
  })

  function moduleFile(name) {
    return moduleFiles[String(name)] || capitalize(name) + ".qml"
  }

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

      // pillModules entries can be a module name ('clock'), a waybar-style
      // custom module object ({ "run": "...", ... }) handled by CustomBarModule.qml,
      // or a tray module object ({ "tray": "<id>" }) handled by TrayModule.qml
      readonly property bool isCustom: typeof modelData === "object" && modelData !== null
      readonly property bool isTray: isCustom && modelData.tray !== undefined
      readonly property string moduleID: isCustom ? "custom" + index : String(modelData)

      // tray entries vanish (Row skips them, no gap) while their app is not running
      function trayItemFor(id) {
        const list = SystemTray.items.values
        for (let i = 0; i < list.length; i++) if (String(list[i].id) === id) return list[i]
        return null
      }
      visible: !isCustom || (isTray ? trayItemFor(String(modelData.tray)) !== null : !!modelData.run)

      Loader {
        id: moduleLoader
        anchors.fill: parent
        source: isTray ? "TrayModule.qml"
              : isCustom ? "CustomBarModule.qml" : moduleFile(modelData)
        // every bar module builds in parallel off the GUI thread, so the pill
        // shows up right away instead of after every module compiled
        asynchronous: true
        onLoaded: {
          if (isTray) {
            item.trayID = String(modelData.tray)
            item.moduleID = moduleID
            return
          }
          if (isCustom) {
            item.spec = modelData
            item.moduleID = moduleID
            return
          }
          switch (modelData) {
            case "volume":
              // The Repeater rebuilds every module whenever Config.pillModules is
              // reassigned (config-app rewrites the JSON). A fresh volume module
              // emits volumeChanged while syncing its initial state, which is not
              // a user action, so ignore signals during a short grace period.
              box.volumeModule = item
              const volumeLoadedAt = Date.now()
              item.volumeChanged.connect(function() {
                if (Date.now() - volumeLoadedAt < 1500) return
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
          ? (isTray || modelData.click
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
