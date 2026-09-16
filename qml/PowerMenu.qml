import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
  id: root

  property bool shown: false
  property string initialAction: ""
  property string pendingAction: "" // "", "shutdown", "reboot", "logout"
  property int selectedIndex: 4     // default to shutdown
  property int confirmIndex: 0      // 0: cancel, 1: confirm — keyboard-only, never set by hover
  property int hoveredButton: -1    // -1: none, 0: cancel, 1: confirm — mouse hover, cosmetic only

  signal closeRequested()

  readonly property real scaleFactor: Config.pillScale
  readonly property var actions: [
    { id: "lock",     label: "Lock",     icon: "\uf023",       accent: "#6791dc" },
    { id: "sleep",    label: "Sleep",    icon: "\udb82\udd04", accent: "#a277ff" },
    { id: "logout",   label: "Logout",   icon: "\udb82\udf43", accent: "#ea9d34" },
    { id: "reboot",   label: "Restart",  icon: "\uead2",       accent: "#f5a938" },
    { id: "shutdown", label: "Shutdown", icon: "\udb81\udc25", accent: "#e22323" }
  ]

  // Commands are launched with Quickshell.execDetached(), NOT Process items.
  // A Process is a child of this Item, and this Item gets destroyed the instant
  // closeRequested() closes the menu (the Loader in shell.qml unloads it) —
  // that was killing shutdown/reboot/lock/sleep before they ever actually ran.
  // execDetached() spawns the command fully independent of this item's lifetime.

  function triggerAction(actId) {
    if (actId === "lock") {
      Quickshell.execDetached(["bash", "-c", Config.screenLockAppCommand])
      closeRequested()
      return
    }
    if (actId === "sleep") {
      Quickshell.execDetached(["bash", "-c", "systemctl suspend"])
      closeRequested()
      return
    }
    if (Config.confirmPowerActions) {
      confirmAction(actId)
    } else {
      executeAction(actId)
    }
  }

  focus: true

  function cancelConfirmation() {
    pendingAction = ""
    initialAction = ""
    hoveredButton = -1
    root.forceActiveFocus()
  }

  function confirmAction(actId) {
    pendingAction = actId
    confirmIndex = 0 // default to Cancel for safety
    hoveredButton = -1 // ignore any stale cursor position from before the dialog opened
    root.forceActiveFocus()
  }

  function executeAction(actId) {
    if (actId === "shutdown") {
      Quickshell.execDetached(["bash", "-c", "systemctl poweroff"])
    } else if (actId === "reboot") {
      Quickshell.execDetached(["bash", "-c", "systemctl reboot"])
    } else if (actId === "logout") {
      Quickshell.execDetached(["bash", "-c", "loginctl terminate-session ${XDG_SESSION_ID:-self} || hyprctl dispatch exit || pkill -KILL -u $USER"])
    }
    cancelConfirmation()
    closeRequested()
  }

  onShownChanged: {
    if (shown) {
      if (initialAction !== "") {
        confirmAction(initialAction)
      } else {
        pendingAction = ""
        selectedIndex = 4
      }
      root.forceActiveFocus()
    } else {
      cancelConfirmation()
    }
  }

  onInitialActionChanged: {
    if (shown && initialAction !== "") {
      confirmAction(initialAction)
    }
  }

  Keys.onPressed: (event) => {
    if (event.key === Qt.Key_Escape) {
      if (pendingAction !== "") {
        cancelConfirmation()
      } else {
        closeRequested()
      }
      event.accepted = true
      return
    }

    if (pendingAction !== "") {
      if (event.key === Qt.Key_Left || event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
        confirmIndex = confirmIndex === 0 ? 1 : 0
        event.accepted = true
      } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
        if (confirmIndex === 1) {
          executeAction(pendingAction)
        } else {
          cancelConfirmation()
        }
        event.accepted = true
      } else if (event.key === Qt.Key_Y) {
        executeAction(pendingAction)
        event.accepted = true
      } else if (event.key === Qt.Key_N) {
        cancelConfirmation()
        event.accepted = true
      }
      return
    }

    if (event.key === Qt.Key_Left) {
      selectedIndex = (selectedIndex - 1 + actions.length) % actions.length
      event.accepted = true
    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
      selectedIndex = (selectedIndex + 1) % actions.length
      event.accepted = true
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
      triggerAction(actions[selectedIndex].id)
      event.accepted = true
    } else if (event.key === Qt.Key_L) {
      triggerAction("lock"); event.accepted = true
    } else if (event.key === Qt.Key_S) {
      triggerAction("sleep"); event.accepted = true
    } else if (event.key === Qt.Key_E) {
      triggerAction("logout"); event.accepted = true
    } else if (event.key === Qt.Key_R) {
      triggerAction("reboot"); event.accepted = true
    } else if (event.key === Qt.Key_P || event.key === Qt.Key_Q) {
      triggerAction("shutdown"); event.accepted = true
    }
  }

  // Mode 1: 5-Button Power Action Selection
  RowLayout {
    anchors.centerIn: parent
    spacing: 14 * root.scaleFactor
    visible: root.pendingAction === ""

    Repeater {
      model: root.actions
      delegate: Item {
        width: 52 * root.scaleFactor
        height: 62 * root.scaleFactor
        Layout.alignment: Qt.AlignVCenter

        property bool isSelected: index === root.selectedIndex
        property bool isHovered: itemMouse.containsMouse

        ColumnLayout {
          anchors.centerIn: parent
          spacing: 5 * root.scaleFactor

          Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 40 * root.scaleFactor
            height: 40 * root.scaleFactor
            radius: 12 * root.scaleFactor
            color: isSelected ? Theme.bg3 : (isHovered ? Theme.bg2 : Theme.bg1)
            border.color: isSelected ? modelData.accent : (isHovered ? Theme.borderBg1 : Theme.borderBg3)
            border.width: isSelected ? 2 : 1
            scale: itemMouse.pressed ? 0.92 : (isSelected ? 1.05 : (isHovered ? 1.03 : 1.0))

            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            Text {
              anchors.centerIn: parent
              text: modelData.icon
              color: isSelected || isHovered ? modelData.accent : Theme.fg3
              font { family: Theme.nerdFontFamily; pixelSize: 15 * root.scaleFactor }
              Behavior on color { ColorAnimation { duration: 120 } }
            }
          }

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: modelData.label
            color: isSelected ? Theme.fg : (isHovered ? Theme.fg2 : Theme.fg5)
            font { family: Theme.fontFamily; pixelSize: 9 * root.scaleFactor; weight: isSelected ? 600 : 400 }
            Behavior on color { ColorAnimation { duration: 120 } }
          }
        }

        MouseArea {
          id: itemMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: root.selectedIndex = index
          onClicked: root.triggerAction(modelData.id)
        }
      }
    }
  }

  // Mode 2: Confirmation Prompt
  ColumnLayout {
    anchors.centerIn: parent
    spacing: 10 * root.scaleFactor
    visible: root.pendingAction !== ""

    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: 8 * root.scaleFactor

      Text {
        text: root.pendingAction === "shutdown" ? "\udb81\udc25" : (root.pendingAction === "reboot" ? "\uead2" : "\udb82\udf43")
        color: root.pendingAction === "shutdown" ? "#e22323" : (root.pendingAction === "reboot" ? "#f5a938" : "#ea9d34")
        font { family: Theme.nerdFontFamily; pixelSize: 14 * root.scaleFactor }
      }

      Text {
        text: root.pendingAction === "shutdown" ? "Shut down system?"
            : (root.pendingAction === "reboot" ? "Restart system?"
            : "Log out of session?")
        color: Theme.fg
        font { family: Theme.fontFamily; pixelSize: 11 * root.scaleFactor; weight: 600 }
      }
    }

    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: 12 * root.scaleFactor

      // Cancel button
      Rectangle {
        width: 86 * root.scaleFactor
        height: 28 * root.scaleFactor
        radius: 8 * root.scaleFactor
        color: (root.confirmIndex === 0 || root.hoveredButton === 0) ? Theme.focusBgL : Theme.bg1
        border.color: (root.confirmIndex === 0 || root.hoveredButton === 0) ? Theme.borderBgFocus : Theme.borderBg3
        border.width: 1
        scale: cancelMouse.pressed ? 0.94 : ((root.confirmIndex === 0 || root.hoveredButton === 0) ? 1.03 : 1.0)
        Behavior on scale { NumberAnimation { duration: 80 } }
        Behavior on color { ColorAnimation { duration: 100 } }

        RowLayout {
          anchors.centerIn: parent
          spacing: 4 * root.scaleFactor
          Text {
            text: "\udb80\udf28" // nf-md-close
            color: Theme.fg4
            font { family: Theme.nerdFontFamily; pixelSize: 11 * root.scaleFactor }
          }
          Text {
            text: "Cancel"
            color: Theme.fg2
            font { family: Theme.fontFamily; pixelSize: 9 * root.scaleFactor; weight: 500 }
          }
        }

        MouseArea {
          id: cancelMouse
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          hoverEnabled: true
          onEntered: root.hoveredButton = 0
          onExited: if (root.hoveredButton === 0) root.hoveredButton = -1
          onClicked: root.cancelConfirmation()
        }
      }

      // Confirm button
      Rectangle {
        width: 86 * root.scaleFactor
        height: 28 * root.scaleFactor
        radius: 8 * root.scaleFactor
        color: root.pendingAction === "shutdown" ? "#e22323" : (root.pendingAction === "reboot" ? "#e08d24" : Theme.accent)
        opacity: (root.confirmIndex === 1 || root.hoveredButton === 1) ? 1.0 : 0.85
        scale: confirmMouse.pressed ? 0.94 : ((root.confirmIndex === 1 || root.hoveredButton === 1) ? 1.03 : 1.0)
        Behavior on scale { NumberAnimation { duration: 80 } }
        Behavior on opacity { NumberAnimation { duration: 100 } }

        RowLayout {
          anchors.centerIn: parent
          spacing: 4 * root.scaleFactor
          Text {
            text: "\udb80\udf29" // nf-md-check
            color: "#ffffff"
            font { family: Theme.nerdFontFamily; pixelSize: 11 * root.scaleFactor }
          }
          Text {
            text: root.pendingAction === "shutdown" ? "Shutdown"
                : (root.pendingAction === "reboot" ? "Restart"
                : "Logout")
            color: "#ffffff"
            font { family: Theme.fontFamily; pixelSize: 9 * root.scaleFactor; weight: 600 }
          }
        }

        MouseArea {
          id: confirmMouse
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          hoverEnabled: true
          onEntered: root.hoveredButton = 1
          onExited: if (root.hoveredButton === 1) root.hoveredButton = -1
          onClicked: root.executeAction(root.pendingAction)
        }
      }
    }
  }
}
