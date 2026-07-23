import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import IslandBackend

PanelWindow {
  id: wifiListWindow

  property real anchorX: 0
  property real anchorY: 0

  anchors.top: true
  anchors.left: true
  margins.top: anchorY
  margins.left: anchorX

  property bool controlCenter: false
  property string passwordPromptSsid: ""
  property bool passwordPromptVisible: false
  property string passwordValue: ""

  // keyboard focus for password prompt
  WlrLayershell.keyboardFocus: passwordPromptVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  exclusionMode: ExclusionMode.Ignore
  width: 290
  height: 380
  color: "transparent"

  // auto hide if control center close
  onVisibleChanged: {
    if (visible && WifiController.enabled) WifiController.refreshNetworks(true)
  }

  Rectangle {
    anchors.fill: parent
    anchors.topMargin: 40
    anchors.rightMargin: 30
    color: "#1c1c1c"
    radius: 15

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 12
      spacing: 13

      Text {
        text: "Wi-Fi"
        color: "#d2d2d2"
        font { family: Theme.fontFamily; pixelSize: 14; bold: true }
        Layout.leftMargin: 5
      }

      Text {
        visible: WifiController.scanning
        text: "Scanning..."
        color: "#949494"
        font { family: Theme.fontFamily; pixelSize: 11 }
      }

      Text {
        visible: !WifiController.enabled
        text: "Turn on the Wi-Fi to see networks."
        color: "#949494"
        font { family: Theme.fontFamily; pixelSize: 11 }
        wrapMode: Text.Wrap
        Layout.fillWidth: true
        Layout.leftMargin: 5
      }

      Flickable {
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentHeight: networkColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: networkColumn
          width: parent.width
          spacing: 4

          Repeater {
            // ssid, display name, type, signal, secure, saved connection and connected
            model: WifiController.enabled ? WifiController.networks : null

            delegate: Rectangle {
              width: networkColumn.width
              height: 50
              radius: 11
              color: connected ? "#4173c4" : (networkMouse.containsMouse ? "#313131" : "#252525")
              border.color: connected ? "" : "#2f2f2f"
              border.width: connected ? 0 : 1

              MouseArea {
                id: networkMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: !WifiController.busy && WifiController.enabled
                onClicked: {
                  if (connected) {
                    WifiController.disconnectCurrent()
                    return
                  }
                  if (savedConnection || !secure) {
                    WifiController.connectToNetwork(ssid)
                    return
                  }
                  wifiListWindow.passwordPromptSsid = ssid
                  wifiListWindow.passwordPromptVisible = true
                }
              }

              Row {
                anchors.fill: parent
                anchors.margins: 12
                anchors.leftMargin: 17
                spacing: 15

                // security type icon (lock/unlock)
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: secure ? "\uf023" : "\uf09c"
                  font { family: Theme.nerdFontFamily; pixelSize: 12 }
                  color: "#b4b4b4"
                }

                Column {
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: 2
                  Text {
                    text: displayName || ssid
                    color: "#ffffff"
                    font { family: Theme.fontFamily; pixelSize: 12; weight: connected ? 500 : 300 }
                  }
                  Text {
                    text: connected ? "Connected" : (signal >= 0 ? signal + "%" : "")
                    color: connected ? "#c8d7ef" : "#949494"
                    elide: Text.ElideRight
                    font { family: Theme.fontFamily; pixelSize: 10 }
                  }
                }
              }
            }
          }
        }
      }

      Text {
        visible: WifiController.errorMessage.length > 0
        text: WifiController.errorMessage
        color: "#e94545"
        font { family: Theme.fontFamily; pixelSize: 11 }
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
      }
    }

    // password prompt overlay box
    Rectangle {
      visible: wifiListWindow.passwordPromptVisible
      onVisibleChanged: if (visible) passwordField.forceActiveFocus()
      anchors.fill: parent
      color: "#272727"
      radius: 13
      z: 10

      MouseArea { anchors.fill: parent }

      Column {
        anchors.centerIn: parent
        width: parent.width - 32
        spacing: 12

        Text {
          width: parent.width
          text: "Password for " + wifiListWindow.passwordPromptSsid
          color: "#e1e1e1"
          font { family: Theme.fontFamily; pixelSize: 13; bold: true }
          wrapMode: Text.Wrap
        }

        Rectangle {
          width: parent.width
          height: 36
          radius: 8
          color: "#404040"
          border.color: "#5a5a5a"
          border.width: 1

          TextInput {
            id: passwordField
            focus: true
            anchors.fill: parent
            anchors.margins: 10
            color: "#dadada"
            font { family: Theme.fontFamily; pixelSize: 12 }
            echoMode: TextInput.Normal
            verticalAlignment: TextInput.AlignVCenter
            onTextChanged: wifiListWindow.passwordValue = text
            Keys.onReturnPressed: submitBtn.clicked()
          }
        }

        Row {
          spacing: 8
          Rectangle {
            id: submitBtn
            width: 80; height: 32; radius: 8
            color: submitBtnMA.containsMouse ? "#3f76d0" : "#3874d7" 
            signal clicked()
            Text { anchors.centerIn: parent; text: "Join"; color: "#fff"; font { family: Theme.fontFamily; pixelSize: 12 } }
            Behavior on color { ColorAnimation { duration: 80 } }
            MouseArea {
              id: submitBtnMA
              hoverEnabled: true
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                WifiController.connectToNetwork(wifiListWindow.passwordPromptSsid, wifiListWindow.passwordValue)
                wifiListWindow.passwordPromptVisible = false
                wifiListWindow.passwordValue = ""
                passwordField.text = ""
              }
            }
          }

          Rectangle {
            width: 80; height: 32; radius: 8
            color: cancelBtnMA.containsMouse ? "#303030" : "#343434"
            Text { anchors.centerIn: parent; text: "Cancel"; color: "#dadada"; font { family: Theme.fontFamily; pixelSize: 12 } }
            Behavior on color { ColorAnimation { duration: 80 } }
            MouseArea {
              id: cancelBtnMA
              hoverEnabled: true
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                wifiListWindow.passwordPromptVisible = false
                wifiListWindow.passwordValue = ""
                passwordField.text = ""
              }
            }
          }
        }
      }
    }
  }
}
