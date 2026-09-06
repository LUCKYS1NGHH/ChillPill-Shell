import QtQuick
import QtQuick.Layouts

RowLayout {
  Layout.alignment: Qt.AlignVCenter

  Text {
    text: "\uf0f3"
    font { family: Config.nerdFontFamily; pixelSize: 10 * box.dpi }
    color: notificationModule.notifications.length > 0 ? "#d8ad5c" : "#9ea9bd"
  }

  Text {
    text: notificationModule.notifications.length
    font { family: Config.textFontFamily; pixelSize: 10 * box.dpi }
    color: Theme.fg
  }

}
