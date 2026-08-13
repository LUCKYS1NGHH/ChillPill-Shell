import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import IslandBackend

PanelWindow {
  id: btListWindow

  readonly property real dpi: Config.dpiScale

  property real anchorX: 0
  property real anchorY: 0

  anchors.top: true
  anchors.left: true
  margins.top: anchorY
  margins.left: anchorX

  // keyboard focus needed whenever the agent wants a PIN/passkey typed in
  WlrLayershell.keyboardFocus: (BluetoothPairingAgent.requestActive && BluetoothPairingAgent.requestRequiresInput)
                                 ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  exclusionMode: ExclusionMode.Ignore
  width: 270 * dpi
  height: 348 * dpi
  color: "transparent"

  onVisibleChanged: {
    if (visible && BluetoothController.enabled) BluetoothController.refreshDevices(true)
  }

  Rectangle {
    anchors.fill: parent
    anchors.topMargin: 40 * dpi
    anchors.rightMargin: 32 * dpi
    color: "#1c1c1c"
    radius: 26 * dpi

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 16 * dpi
      spacing: 13 * dpi

      Text {
        text: "Bluetooth"
        color: "#d2d2d2"
        font { family: Theme.fontFamily; pixelSize: 14 * dpi; bold: true }
        Layout.leftMargin: 5 * dpi
      }

      Text {
        visible: BluetoothController.enabled && BluetoothController.adapterName.length > 0
        text: "Visible as \u201c" + BluetoothController.adapterName + "\u201d"
        color: "#7d7d7d"
        font { family: Theme.fontFamily; pixelSize: 10 * dpi }
        wrapMode: Text.Wrap
        Layout.fillWidth: true
        Layout.leftMargin: 5 * dpi
      }

      Text {
        visible: BluetoothController.scanning
        text: "Scanning..."
        color: "#949494"
        font { family: Theme.fontFamily; pixelSize: 11 * dpi }
      }

      Text {
        visible: !BluetoothController.enabled
        text: "Turn on Bluetooth to see devices."
        color: "#949494"
        font { family: Theme.fontFamily; pixelSize: 11 * dpi }
        wrapMode: Text.Wrap
        Layout.fillWidth: true
        Layout.leftMargin: 5 * dpi
      }

      Flickable {
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentHeight: deviceColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: deviceColumn
          width: parent.width
          spacing: 4 * dpi

          Repeater {
            // name, address, paired, connected, signal
            model: BluetoothController.enabled ? BluetoothController.devices : null

            delegate: Rectangle {
              width: deviceColumn.width
              height: Math.max(45, contentRow.implicitHeight + 15)
              radius: 16 * dpi
              color: connected ? "#4173c4" : (deviceMouse.containsMouse ? "#313131" : "#252525")
              border.color: connected ? "" : "#2f2f2f"
              border.width: connected ? 0 : 1

              MouseArea {
                id: deviceMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                enabled: !BluetoothController.busy && BluetoothController.enabled
                onClicked: (mouse) => {
                  console.log("device click:", address, "button:", mouse.button, "paired:", paired)
                  if (mouse.button === Qt.RightButton) {
                    if (paired) BluetoothController.forgetDevice(address)
                    return
                  }
                  if (connected) {
                    BluetoothController.disconnectDevice(address)
                    return
                  }
                  if (paired) {
                    BluetoothController.connectDevice(address)
                    return
                  }
                  BluetoothController.pairDevice(address)
                }
              }

              Row {
                id: contentRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 17 * dpi
                anchors.rightMargin: 10 * dpi
                spacing: 20 * dpi

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: connected ? "\uf5b0" : paired ? "\uf0c1" : "\uf294" // dynamic glyph
                  font { family: Theme.nerdFontFamily; pixelSize: 12 * dpi }
                  color: "#b4b4b4"
                }

                Column {
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - 20 - 20 // minus icon width + spacing, roughly
                  spacing: 2 * dpi
                  Text {
                    text: name
                    color: "#ffffff"
                    font { family: Theme.fontFamily; pixelSize: 11 * dpi; weight: connected ? 500 : 300 }
                  }
                  Text {
                    width: parent.width
                    text: connected ? "Connected" : (paired ? "Paired \u2022 right-click to forget" : "Not paired")
                    color: connected ? "#c8d7ef" : "#949494"
                    wrapMode: Text.WordWrap
                    font { family: Theme.fontFamily; pixelSize: 9 * dpi }
                  }
                }
              }
            }
          }
        }
      }

      Text {
        visible: BluetoothController.errorMessage.length > 0
        text: BluetoothController.errorMessage
        color: "#e94545"
        font { family: Theme.fontFamily; pixelSize: 11 * dpi }
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
      }
    }

    // pairing request overlay - driven entirely by BluetoothPairingAgent
    Rectangle {
      visible: BluetoothPairingAgent.requestActive
      onVisibleChanged: if (visible && BluetoothPairingAgent.requestRequiresInput) secretField.forceActiveFocus()
      anchors.fill: parent
      color: "#1c1c1c"
      radius: 28 * dpi
      z: 10

      MouseArea { anchors.fill: parent }

      Column {
        anchors.centerIn: parent
        width: parent.width - 32 * dpi
        spacing: 12 * dpi

        Text {
          width: parent.width
          text: BluetoothPairingAgent.promptTitle.length > 0
                  ? BluetoothPairingAgent.promptTitle
                  : ("Pair with " + BluetoothPairingAgent.deviceName)
          color: "#e1e1e1"
          font { family: Theme.fontFamily; pixelSize: 13 * dpi; weight: 600 }
          wrapMode: Text.Wrap
        }

        Text {
          visible: BluetoothPairingAgent.promptMessage.length > 0
          width: parent.width
          text: BluetoothPairingAgent.promptMessage
          color: "#949494"
          font { family: Theme.fontFamily; pixelSize: 11 * dpi }
          wrapMode: Text.Wrap
        }

        // case 1: agent wants a PIN or passkey typed in (RequestPinCode / RequestPasskey)
        Rectangle {
          visible: BluetoothPairingAgent.requestRequiresInput
          width: parent.width
          height: 36 * dpi
          radius: 8 * dpi
          color: "#3a3a3a"
          border.color: "#5a5a5a"
          border.width: 1

          TextInput {
            id: secretField
            anchors.fill: parent
            anchors.margins: 10 * dpi
            color: "#dadada"
            font { family: Theme.fontFamily; pixelSize: 12 * dpi }
            echoMode: TextInput.Normal
            verticalAlignment: TextInput.AlignVCenter
            inputMethodHints: BluetoothPairingAgent.requestNumericInput ? Qt.ImhDigitsOnly : Qt.ImhNone
            validator: BluetoothPairingAgent.requestNumericInput ? intValidator : null
            IntValidator { id: intValidator; bottom: 0 }
            Keys.onReturnPressed: pairSubmitBtn.clicked()
          }
        }

        // case 2: agent just wants us to display a code (DisplayPinCode / DisplayPasskey)
        Text {
          visible: !BluetoothPairingAgent.requestRequiresInput && !BluetoothPairingAgent.requestRequiresConfirmation
                   && BluetoothPairingAgent.displayedCode.length > 0
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: BluetoothPairingAgent.displayedCode
          color: "#ffffff"
          font { family: Theme.fontFamily; pixelSize: 22 * dpi; bold: true; letterSpacing: 3 }
        }

        // case 3: agent wants a yes/no confirmation of a shown passkey (RequestConfirmation)
        Text {
          visible: BluetoothPairingAgent.requestRequiresConfirmation
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: BluetoothPairingAgent.displayedCode
          color: "#ffffff"
          font { family: Theme.fontFamily; pixelSize: 22 * dpi; bold: true; letterSpacing: 3 }
        }

        Row {
          spacing: 8 * dpi

          // Join/Confirm - shown for input case and confirmation case (RequestAuthorization/AuthorizeService also confirm-style)
          Rectangle {
            id: pairSubmitBtn
            visible: BluetoothPairingAgent.requestRequiresInput || BluetoothPairingAgent.requestRequiresConfirmation
            width: 80 * dpi; height: 32 * box.dpi; radius: 9 * box.dpi
            color: pairSubmitMA.containsMouse ? "#3065be" : "#3874d7"
            signal clicked()
            Text {
              anchors.centerIn: parent
              text: BluetoothPairingAgent.requestRequiresInput ? "Pair" : "Confirm"
              color: "#fff"
              font { family: Theme.fontFamily; pixelSize: 12 * dpi}
            }
            Behavior on color { ColorAnimation { duration: 80 } }
            MouseArea {
              id: pairSubmitMA
              hoverEnabled: true
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (BluetoothPairingAgent.requestRequiresInput) {
                  BluetoothPairingAgent.submitSecret(secretField.text)
                  secretField.text = ""
                } else {
                  BluetoothPairingAgent.confirmRequest()
                }
              }
            }
          }

          // OK - shown for the passive display-only case, just acknowledges/cancels
          Rectangle {
            visible: !BluetoothPairingAgent.requestRequiresInput && !BluetoothPairingAgent.requestRequiresConfirmation
            width: 80 * dpi; height: 32 * box.dpi; radius: 9 * box.dpi
            color: okMA.containsMouse ? "#3065be" : "#3874d7"
            Text { anchors.centerIn: parent; text: "OK"; color: "#fff"; font { family: Theme.fontFamily; pixelSize: 12 * dpi } }
            Behavior on color { ColorAnimation { duration: 80 } }
            MouseArea {
              id: okMA
              hoverEnabled: true
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: BluetoothPairingAgent.cancelRequest()
            }
          }

          Rectangle {
            width: 80 * dpi; height: 32 * box.dpi; radius: 9 * box.dpi
            color: cancelMA.containsMouse ? "#2f2f2f" : "#343434"
            Text {
              anchors.centerIn: parent
              text: BluetoothPairingAgent.requestRequiresConfirmation ? "Reject" : "Cancel"
              color: "#dadada"
              font { family: Theme.fontFamily; pixelSize: 12 * dpi }
            }
            Behavior on color { ColorAnimation { duration: 80 } }
            MouseArea {
              id: cancelMA
              hoverEnabled: true
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              visible: BluetoothPairingAgent.requestRequiresInput || BluetoothPairingAgent.requestRequiresConfirmation
              onClicked: {
                if (BluetoothPairingAgent.requestRequiresConfirmation) {
                  BluetoothPairingAgent.rejectRequest()
                } else {
                  BluetoothPairingAgent.cancelRequest()
                  secretField.text = ""
                }
              }
            }
          }
        }
      }
    }
  }
}
