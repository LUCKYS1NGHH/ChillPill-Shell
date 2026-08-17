import Quickshell
import QtQuick
import QtQuick.Layouts

Rectangle {
  id: calendarPopup
  property bool shown: false
  visible: opacity > 0
  opacity: shown ? 1 : 0
  width: 225 * box.dpi
  height: daysGrid.y + daysGrid.height + 12 * box.dpi
  x: (parent.width - calendarPopup.width) / 2
  y: box.y + box.height * box.dpi + 5 * box.dpi
  color: Theme.bg
  radius: 18 * box.dpi
  Behavior on opacity { NumberAnimation { duration: 225; easing.type: Easing.OutExpo } }
  Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutExpo } }

  RowLayout {
    id: calHeader
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: 12 * box.dpi
    anchors.topMargin: 8 * box.dpi
    height: 25 * box.dpi
    Item { Layout.fillWidth: true }
    Text {
      text: datetimeItem.monthNames[datetimeItem.viewMonth] + " " + datetimeItem.viewYear
      color: Theme.fg
      font { family: Theme.fontFamily; pixelSize: 11 * box.dpi; weight: 600 }
    }
    Item { Layout.fillWidth: true }
  }

  Grid {
    id: dayHeaders
    columns: 7
    anchors.top: calHeader.bottom
    anchors.topMargin: 6 * box.dpi
    anchors.horizontalCenter: parent.horizontalCenter
    columnSpacing: 4 * box.dpi
    Repeater {
      model: datetimeItem.dayNames
      Text {
        width: 25 * box.dpi; text: modelData; color: Theme.fg5
        font { family: Theme.fontFamily; pixelSize: 8 * box.dpi; weight: 600 }
        horizontalAlignment: Text.AlignHCenter
      }
    }
  }

  Grid {
    id: daysGrid
    columns: 7
    anchors.top: dayHeaders.bottom
    anchors.topMargin: 4 * box.dpi
    anchors.horizontalCenter: parent.horizontalCenter
    columnSpacing: 4 * box.dpi; rowSpacing: 2 * box.dpi
    Repeater {
      model: datetimeItem.firstDayOfMonth(datetimeItem.viewYear, datetimeItem.viewMonth)
      Item { width: 26 * box.dpi; height: 22 * box.dpi }
    }
    Repeater {
      model: datetimeItem.daysInMonth(datetimeItem.viewYear, datetimeItem.viewMonth)
      delegate: Rectangle {
        width: 26 * box.dpi; height: 22 * box.dpi; radius: 6 * box.dpi
        property bool isToday: {
          var today = new Date()
          return index + 1 === today.getDate()
            && datetimeItem.viewMonth === today.getMonth()
            && datetimeItem.viewYear === today.getFullYear()
        }
        color: isToday ? "#ec3737" : "transparent"
        Text {
          anchors.centerIn: parent
          text: index + 1
          color: isToday ? "#1c1c1c" : Theme.fg
          font { family: Theme.fontFamily; pixelSize: 9 * box.dpi; weight: isToday ? 700 : 400 }
        }
      }
    }
  }
}
