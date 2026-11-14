import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import QtQuick

//  TrayModule.qml - system tray icon as a pill bar module
//
//  Rendered for {"tray": "<id>"} entries in Config.pillModules, where <id>
//  is the StatusNotifierItem's Id (SystemTrayItem.id, e.g. "nm-applet").
//  Left click activates (or opens the menu for menu-only items), middle
//  click does the secondary action, right click opens the menu.

Item {
  id: root

  property string trayID: ""   // SystemTrayItem id, assigned by PillBarModules
  property string moduleID: "" // for the shared bar tooltip

  readonly property var item: {
    const list = SystemTray.items.values
    for (let i = 0; i < list.length; i++) if (list[i].id === trayID) return list[i]
    return null
  }

  // read by PillBarModules to feed the shared bar tooltip
  readonly property string tooltipText: item === null ? ""
    : item.tooltipDescription !== "" && item.tooltipTitle !== ""
      ? item.tooltipTitle + "\n" + item.tooltipDescription
      : item.tooltipTitle !== "" ? item.tooltipTitle : item.tooltipDescription

  visible: item !== null
  implicitWidth: icon.implicitWidth
  implicitHeight: icon.implicitHeight

  QsMenuAnchor {
    id: menuAnchor
    menu: root.item !== null ? root.item.menu : null
    anchor.item: root
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.margins.top: 6
  }

  IconImage {
    id: icon
    anchors.centerIn: parent
    visible: root.item !== null
    source: root.item !== null ? root.item.icon : ""
    implicitSize: Math.max(11, Math.round(13 * Config.pillScale))
    opacity: root.item !== null && root.item.status === Status.Passive ? 0.45 : 1
  }

  TapHandler {
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    onTapped: (eventPoint, button) => {
      if (root.item === null) return
      if (button === Qt.LeftButton) {
        if (root.item.onlyMenu) menuAnchor.open()
        else root.item.activate()
      } else if (button === Qt.MiddleButton) {
        if (!root.item.onlyMenu) root.item.secondaryActivate()
      } else if (button === Qt.RightButton) {
        menuAnchor.open()
      }
    }
  }

  WheelHandler {
    onWheel: (wheel) => {
      if (root.item === null) return
      root.item.scroll(wheel.angleDelta.y > 0 ? 1 : -1, false)
    }
  }
}
