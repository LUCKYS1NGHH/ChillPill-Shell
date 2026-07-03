import QtQuick
import QtQuick.Layouts

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
