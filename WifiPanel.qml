import Quickshell
import QtQuick
import IslandBackend

PanelWindow {
  id: wifiListWindow

  property string passwordPromptSsid: ""
  property bool passwordPromptVisible: false
  property string passwordValue: ""

  property string fontFamily: Theme.fontFamily
  property string bg: Theme.bg
  property string accent: Theme.accent

  exclusionMode: ExclusionMode.Ignore
  width: 275
  height: 420
  color: "transparent"

  anchors.top: true
  anchors.left: true
  margins.top: 25
  margins.left: 180

  onVisibleChanged: {
      if (visible && WifiController.enabled)
          WifiController.refreshNetworks(true)
  }

  Rectangle {
    anchors.fill: parent
    color: "#1f1f1f"
    radius: 13

    Column {
      anchors.fill: parent
      anchors.margins: 12
      spacing: 10

      Text {
          text: "Wi-Fi"
          color: "#dadada"
          font.pixelSize: 14
          font.bold: true
          font.family: fontFamily
      }

      Text {
          visible: WifiController.scanning
          text: "Scanning..."
          color: "#888"
          font.pixelSize: 11
          font.family: fontFamily
      }

      Text {
          visible: !WifiController.enabled
          text: "Turn on Wi-Fi to see networks."
          color: "#888"
          font.pixelSize: 11
          wrapMode: Text.Wrap
          width: parent.width
          font.family: fontFamily
      }

      Flickable {
          width: parent.width
          height: 300
          contentHeight: networkColumn.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds

          Column {
            id: networkColumn
            width: parent.width
            spacing: 4

            Repeater {
              model: WifiController.enabled ? WifiController.networks : null

              delegate: Rectangle {
                  width: networkColumn.width
                  height: 52
                  radius: 10
                  color: model.connected ? accent : (networkMouse.containsMouse ? "#3a3a3a" : "#333333")

                  MouseArea {
                      id: networkMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      enabled: !WifiController.busy
                      onClicked: {
                          if (model.connected) {
                              WifiController.disconnectCurrent()
                          } else if (model.savedConnection || !model.secure) {
                              WifiController.connectToNetwork(model.ssid)
                          } else {
                              wifiListWindow.passwordPromptSsid = model.ssid
                              wifiListWindow.passwordPromptVisible = true
                          }
                      }
                  }

                  Row {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: model.secure ? "\uf023" : "\uf09c" // icon: lock / unlock 
                      font.family: "FiraCode Nerd Font Propo"
                      font.pixelSize: 12
                      color: "#aaa"
                    }

                    Column {
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: 2

                      Text {
                          text: model.ssid
                          color: "#ffffff"
                          font.pixelSize: 12
                          font.bold: model.connected
                          font.family: fontFamily
                      }

                      Text {
                          text: model.connected ? "Connected" : (model.signal + "%")
                          color: model.connected ? "#a0d4ff" : "#888"
                          font.pixelSize: 10
                          font.family: fontFamily
                      }
                  }
                }
              }
            }
        }
    }
}

// password prompt overlay
Rectangle {
    visible: wifiListWindow.passwordPromptVisible
    anchors.fill: parent
    color: "#2a2a2a"
    radius: 12
    z: 10

    MouseArea { anchors.fill: parent }

    Column {
      anchors.centerIn: parent
      width: parent.width - 32
      spacing: 12

      Text {
        width: parent.width
        text: "Password for " + wifiListWindow.passwordPromptSsid
        color: "#dadada"
        font.pixelSize: 13
        font.bold: true
        wrapMode: Text.Wrap
        font.family: fontFamily
      }

      Rectangle {
        width: parent.width
        height: 36
        radius: 8
        color: "#3a3a3a"
        border.color: "#555"
        border.width: 1

        TextInput {
          id: passwordField
          anchors.fill: parent
          anchors.margins: 10
          activeFocusOnTab: true
          color: "#dadada"
          font.pixelSize: 12
          font.family: fontFamily
          echoMode: TextInput.Normal
          verticalAlignment: TextInput.AlignVCenter
          onTextChanged: wifiListWindow.passwordValue = text
          Keys.onReturnPressed: {
              WifiController.connectToNetwork(wifiListWindow.passwordPromptSsid, wifiListWindow.passwordValue)
              wifiListWindow.passwordPromptVisible = false
              wifiListWindow.passwordValue = ""
              passwordField.text = ""
          }
        }
      }

      Row {
        spacing: 8

        Rectangle {
          width: 80; height: 32; radius: 8
          color: accent
          Text { anchors.centerIn: parent; text: "Join"; color: "#fff"; font.pixelSize: 12; font.family: fontFamily }
          MouseArea {
            anchors.fill: parent
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
            color: "#3a3a3a"
            Text { anchors.centerIn: parent; text: "Cancel"; color: "#dadada"; font.pixelSize: 12; font.family: fontFamily }
            MouseArea {
              anchors.fill: parent
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
