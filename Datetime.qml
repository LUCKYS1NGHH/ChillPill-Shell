import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
  id: root
  implicitWidth: dateLabel.implicitWidth
  implicitHeight: dateLabel.implicitHeight

  property var currentDate: new Date()
  property int viewYear: currentDate.getFullYear()
  property int viewMonth: currentDate.getMonth()
  property string dateFg: "#9d9d9d"

  readonly property var monthNames: ["January","February","March","April","May","June","July","August","September","October","November","December"]
  readonly property var dayNames: ["Su","Mo","Tu","We","Th","Fr","Sa"]

  function daysInMonth(y, m) { return new Date(y, m + 1, 0).getDate() }
  function firstDayOfMonth(y, m) { return new Date(y, m, 1).getDay() }

  Text {
    id: dateLabel
    text: Qt.formatDateTime(clock.date, "hh:mm a ddd, dd MMM yyyy")
    color: dateFg
    font {
      family: Theme.fontFamily
      weight: 500
      pixelSize: 10
      letterSpacing: -0.5
    }
    MouseArea {
      anchors.fill: parent
      onClicked: {
        root.currentDate = new Date()
        root.viewYear = root.currentDate.getFullYear()
        root.viewMonth = root.currentDate.getMonth()
        calendarPopup.opacity = calendarPopup.opacity > 0 ? 0 : 1
      }
    }
  }

  Rectangle {
    id: calendarPopup
    visible: opacity > 0
    opacity: 0
    width: 240
    height: 200
    anchors.top: dateLabel.bottom
    anchors.topMargin: 15
    anchors.horizontalCenter: dateLabel.horizontalCenter
    color: "#1e1e1e"
    radius: 15
    layer.enabled: true

    Behavior on opacity {
      NumberAnimation { duration: 500; easing.type: Easing.OutExpo }
    }

    // header
    RowLayout {
      id: calHeader
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.margins: 12
      anchors.topMargin: 10
      height: 24

      Item { Layout.fillWidth: true }

      Text {
        text: root.monthNames[root.viewMonth] + " " + root.viewYear
        color: Theme.fg
        font { family: Theme.fontFamily; pixelSize: 11; weight: 600 }
      }

      Item { Layout.fillWidth: true }
    }

    // day name headers
    Grid {
      id: dayHeaders
      columns: 7
      anchors.top: calHeader.bottom
      anchors.topMargin: 6
      anchors.horizontalCenter: parent.horizontalCenter
      columnSpacing: 4

      Repeater {
        model: root.dayNames
        Text {
          width: 25
          text: modelData
          color: "#666"
          font { family: Theme.fontFamily; pixelSize: 8; weight: 600 }
          horizontalAlignment: Text.AlignHCenter
        }
      }
    }

    // day grid
    Grid {
      columns: 7
      anchors.top: dayHeaders.bottom
      anchors.topMargin: 4
      anchors.horizontalCenter: parent.horizontalCenter
      columnSpacing: 4
      rowSpacing: 2

      // offset empty cells
      Repeater {
        model: root.firstDayOfMonth(root.viewYear, root.viewMonth)
        Item { width: 26; height: 22 }
      }

      // day numbers
      Repeater {
        model: root.daysInMonth(root.viewYear, root.viewMonth)
        delegate: Rectangle {
          width: 26
          height: 22
          radius: 6
          property bool isToday: {
            var today = new Date()
            return index + 1 === today.getDate()
              && root.viewMonth === today.getMonth()
              && root.viewYear === today.getFullYear()
          }
          color: isToday ? "#e83131" : "transparent"

          Text {
            anchors.centerIn: parent
            text: index + 1
            color: isToday ? "#1e1e1e" : Theme.fg
            font { family: Theme.fontFamily; pixelSize: 9; weight: isToday ? 700 : 400 }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
          }
        }
      }
    }
  }
}
