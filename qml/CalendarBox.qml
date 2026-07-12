import Quickshell
import QtQuick
import QtQuick.Layouts

Rectangle {
  id: calendarPopup
  property bool shown: false
  visible: opacity > 0
  opacity: shown ? 1 : 0
  width: 225
  height: 187
  x: (parent.width - calendarPopup.width) / 2
  y: box.y + box.height + 5
  color: "#1e1e1e"
  radius: 18

  Behavior on opacity { NumberAnimation { duration: 225; easing.type: Easing.OutExpo } }

  RowLayout {
    id: calHeader
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: 12
    anchors.topMargin: 8
    height: 25

    Item { Layout.fillWidth: true }

    Text {
      text: datetimeItem.monthNames[datetimeItem.viewMonth] + " " + datetimeItem.viewYear
      color: Theme.fg
      font { family: Theme.fontFamily; pixelSize: 11; weight: 600 }
    }

    Item { Layout.fillWidth: true }

    }

  Grid {
    id: dayHeaders
    columns: 7
    anchors.top: calHeader.bottom
    anchors.topMargin: 6
    anchors.horizontalCenter: parent.horizontalCenter
    columnSpacing: 4
    Repeater {
      model: datetimeItem.dayNames
      Text {
        width: 25; text: modelData; color: "#6a6a6a"
        font { family: Theme.fontFamily; pixelSize: 8; weight: 600 }
        horizontalAlignment: Text.AlignHCenter
      }
    }
  }

  Grid {
    columns: 7
    anchors.top: dayHeaders.bottom
    anchors.topMargin: 4
    anchors.horizontalCenter: parent.horizontalCenter
    columnSpacing: 4; rowSpacing: 2

    Repeater {
      model: datetimeItem.firstDayOfMonth(datetimeItem.viewYear, datetimeItem.viewMonth)
      Item { width: 26; height: 22 }
    }
    Repeater {
      model: datetimeItem.daysInMonth(datetimeItem.viewYear, datetimeItem.viewMonth)
      delegate: Rectangle {
        width: 26; height: 22; radius: 6
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
          font { family: Theme.fontFamily; pixelSize: 9; weight: isToday ? 700 : 400 }
        }
      }
    }
  }
}
