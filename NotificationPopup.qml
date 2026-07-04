import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Item {
  id: root
  property bool active: false
  property var notif: null

  anchors.centerIn: parent
  opacity: active ? 1 : 0
  visible: opacity > 0
  Behavior on opacity { NumberAnimation { duration: 150 } }

  RowLayout {
    anchors.centerIn: parent
    spacing: 10

    Text {
      text: String.fromCodePoint(0xf0f3)
      color: Theme.fg
      font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
      visible: notifIcon.status !== Image.Ready
    }

    Image {
      id: notifIcon
      width: 22
      height: 22
      fillMode: Image.PreserveAspectCrop
      source: {
        if (root.notif && root.notif.image) return root.notif.image
        if (root.notif && root.notif.appIcon) {
          return root.notif.appIcon.startsWith("/") 
            ? "file://" + root.notif.appIcon 
            : "image://icon/" + root.notif.appIcon
        }
        return ""
      }
      sourceSize: Qt.size(22, 22)
      visible: status === Image.Ready
    }

    ColumnLayout {
      spacing: 2
      Text {
        text: root.notif ? root.notif.summary : ""
        color: Theme.fg
        font { family: Theme.fontFamily; pixelSize: 10; weight: 600 }
        elide: Text.ElideRight
        Layout.maximumWidth: 220
      }

      Text {
        text: root.notif ? root.notif.body : ""
        color: "#9b9b9b"
        font { family: Theme.fontFamily; pixelSize: 9 }
        elide: Text.ElideRight
        Layout.maximumWidth: 220
        visible: text !== ""
      }
    }
  }
}
