import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Rectangle {
  id: calendarPopup
  property bool shown: false
  property var holidays: ({})       // "YYYY-M-D" -> holiday name
  property int tooltipDay: -1       // which day's tooltip is open, -1 = none
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

  onShownChanged: if (shown) holidayLoader.ensureLoaded()

  property string cachePath: `${Quickshell.env("HOME")}/.cache/chillpill-shell/events_${Config.country}_${datetimeItem.viewYear}.json`

  FileView {
    id: holidaysFile
    path: calendarPopup.cachePath
    watchChanges: false
    onLoaded: {
      try { holidays = JSON.parse(text()) }
      catch (e) { holidays = {} }
    }
    onLoadFailed: holidayFetcher.running = true
  }

  Process {
    id: holidayFetcher
    command: [
      "/usr/share/chillpill-shell/scripts/calendar_events.py",
      Config.country,
      datetimeItem.viewYear.toString(),
      calendarPopup.cachePath
    ]
    onExited: holidaysFile.reload()
  }

  QtObject {
    id: holidayLoader
    function ensureLoaded() {
      holidaysFile.reload()
    }
  }

  // re-fetch whenever the visible year changes and cache isn't there yet
  onCachePathChanged: if (shown) holidaysFile.reload()

  RowLayout {
    id: calHeader
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.leftMargin: 16 * box.dpi
    anchors.rightMargin: 16 * box.dpi
    anchors.topMargin: 8 * box.dpi
    height: 25 * box.dpi

    Text {
      id: prevBtn
      text: "\uf053"
      color: prevArea.pressed ? Theme.fg : Theme.fg6
      font { family: "Symbols Nerd Font"; pixelSize: 11 * box.dpi }
      Layout.alignment: Qt.AlignVCenter
      scale: prevArea.pressed ? 0.85 : 1.0
      Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
      Behavior on color { ColorAnimation { duration: 100 } }
      MouseArea {
        id: prevArea
        anchors.fill: parent
        anchors.margins: -8 * box.dpi
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          tooltipDay = -1
          if (datetimeItem.viewMonth === 0) {
            datetimeItem.viewMonth = 11
            datetimeItem.viewYear -= 1
          } else {
            datetimeItem.viewMonth -= 1
          }
        }
      }
    }

    Item { Layout.fillWidth: true }
    Text {
      text: datetimeItem.monthNames[datetimeItem.viewMonth] + " " + datetimeItem.viewYear
      color: Theme.fg
      font { family: Theme.fontFamily; pixelSize: 11 * box.dpi; weight: 600 }
      Layout.alignment: Qt.AlignVCenter
    }
    Item { Layout.fillWidth: true }

    Text {
      id: nextBtn
      text: "\uf054"
      color: nextArea.pressed ? Theme.fg : Theme.fg6
      font { family: "Symbols Nerd Font"; pixelSize: 11 * box.dpi }
      Layout.alignment: Qt.AlignVCenter
      scale: nextArea.pressed ? 0.85 : 1.0
      Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
      Behavior on color { ColorAnimation { duration: 100 } }
      MouseArea {
        id: nextArea
        anchors.fill: parent
        anchors.margins: -8 * box.dpi
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          tooltipDay = -1
          if (datetimeItem.viewMonth === 11) {
            datetimeItem.viewMonth = 0
            datetimeItem.viewYear += 1
          } else {
            datetimeItem.viewMonth += 1
          }
        }
      }
    }
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
        id: dayCell
        width: 26 * box.dpi; height: 22 * box.dpi; radius: 6 * box.dpi
        property bool isToday: {
          var today = new Date()
          return index + 1 === today.getDate()
            && datetimeItem.viewMonth === today.getMonth()
            && datetimeItem.viewYear === today.getFullYear()
        }
        property string holidayKey: `${datetimeItem.viewYear}-${datetimeItem.viewMonth + 1}-${index + 1}`
        property string holidayName: calendarPopup.holidays[holidayKey] || ""
        property bool isHoliday: holidayName !== ""

        color: isToday ? "#ec3737" : "transparent"
        border.color: (!isToday && isHoliday) ? Theme.fg7 : "transparent"
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: index + 1
          color: isToday ? Theme.bgD : (isHoliday ? "#ec3737" : Theme.fg)
          font { family: Theme.fontFamily; pixelSize: 9 * box.dpi; weight: (isToday || isHoliday) ? 700 : 300 }
        }

        MouseArea {
          anchors.fill: parent
          enabled: dayCell.isHoliday
          cursorShape: dayCell.isHoliday ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: calendarPopup.tooltipDay = (calendarPopup.tooltipDay === index) ? -1 : index
        }
      }
    }
  }

  // event name popup
  Rectangle {
    id: holidayTip
    visible: opacity > 0
    opacity: calendarPopup.tooltipDay !== -1 ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 120 } }
    color: "#1c1c1c"
    radius: 8 * box.dpi
    width: tipText.implicitWidth + 18 * box.dpi
    height: tipText.implicitHeight + 12 * box.dpi
    anchors.top: daysGrid.bottom
    anchors.topMargin: 17 * box.dpi
    anchors.horizontalCenter: parent.horizontalCenter

    Text {
      id: tipText
      anchors.centerIn: parent
      color: Theme.fg
      font { family: Theme.fontFamily; pixelSize: 9 * box.dpi; weight: 500 }
      text: calendarPopup.tooltipDay !== -1
        ? (calendarPopup.holidays[`${datetimeItem.viewYear}-${datetimeItem.viewMonth + 1}-${calendarPopup.tooltipDay + 1}`] || "")
        : ""
    }
  }
}
