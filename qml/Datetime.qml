import Quickshell
import QtQuick

Item {
  id: root
  implicitWidth: dateLabel.implicitWidth
  implicitHeight: dateLabel.implicitHeight

  property string dateFg: "#9d9d9d"
  property int viewYear: new Date().getFullYear()
  property int viewMonth: new Date().getMonth()

  readonly property var monthNames: ["January","February","March","April","May","June","July","August","September","October","November","December"]
  readonly property var dayNames: ["Su","Mo","Tu","We","Th","Fr","Sa"]

  function daysInMonth(y, m) { return new Date(y, m + 1, 0).getDate() }
  function firstDayOfMonth(y, m) { return new Date(y, m, 1).getDay() }

  signal toggleCalendar

  Text {
    id: dateLabel
    text: Qt.formatDateTime(clock.date, "hh:mm a ddd, dd MMM yyyy")
    color: dateFg
    font { family: Theme.fontFamily; weight: 500; pixelSize: 10; letterSpacing: -0.5 }

    // call calendar to popup on left click
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        root.viewYear = new Date().getFullYear()
        root.viewMonth = new Date().getMonth()
        root.toggleCalendar()
      }
    }
  }
}
