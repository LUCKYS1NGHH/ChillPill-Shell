import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Rectangle {
  id: calendarPopup
  property bool shown: false
  property var holidays: ({})       // "YYYY-M-D" -> holiday name
  property int tooltipDay: -1       // which day's tooltip is open, -1 = none
  // the calendar owns its month/year state, it used to live in the mini
  // dashboard's Datetime which is unloaded while the dashboard is closed
  property int viewYear: new Date().getFullYear()
  property int viewMonth: new Date().getMonth()

  readonly property var monthNames: ["January","February","March","April","May","June","July","August","September","October","November","December"]
  readonly property var dayNames: ["Su","Mo","Tu","We","Th","Fr","Sa"]

  function daysInMonth(y, m) { return new Date(y, m + 1, 0).getDate() }
  function firstDayOfMonth(y, m) { return new Date(y, m, 1).getDay() }
  function resetView() {
    viewYear = new Date().getFullYear()
    viewMonth = new Date().getMonth()
  }
  visible: opacity > 0
  opacity: shown ? 1 : 0
  width: 225 * box.dpi
  height: daysGrid.y + daysGrid.height + 12 * box.dpi
  x: 0
  y: 0    // the loader positions this popup, see calendarLoader in shell.qml
  color: Theme.bg
  radius: 18 * box.dpi
  layer.enabled: calendarPopup.opacity > 0
  layer.effect: PanelShadow {}
  Behavior on opacity { NumberAnimation { duration: 225; easing.type: Easing.OutExpo } }
  Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutExpo } }

  onShownChanged: if (shown) holidayLoader.ensureLoaded()

  property bool holidaysEnabled: Config.holidaysUsable()
  property bool fetchFailed: false
  property string cachePath: holidaysEnabled
    ? `${Quickshell.env("HOME")}/.cache/chillpill-shell/${Config.holidaysCacheName(calendarPopup.viewYear)}`
    : ""

  // toggling holidays off must clear the highlighted days too
  onHolidaysEnabledChanged: {
    if (!holidaysEnabled) {
      holidays = ({})
      tooltipDay = -1
      fetchFailed = false
    } else if (shown) {
      fetchFailed = false
      holidaysFile.reload()
    }
  }

  FileView {
    id: holidaysFile
    path: calendarPopup.cachePath
    watchChanges: false
    onLoaded: {
      try { holidays = JSON.parse(text()) }
      catch (e) { holidays = {} }
    }
    onLoadFailed: {
      if (calendarPopup.holidaysEnabled && !calendarPopup.fetchFailed) {
        holidayFetcher.running = true
      }
    }
  }

  function holidayArgs() {
    const a = [
      "/usr/share/chillpill-shell/scripts/calendar_events.py",
      Config.country.trim(),
      calendarPopup.viewYear.toString(),
      calendarPopup.cachePath
    ]
    if (Config.holidaysAllCategories) a.push("--all")
    else if (Config.holidaysCategories.trim()) a.push("--categories", Config.holidaysCategories.trim())
    const sub = Config.holidaysSubdiv.trim()
    if (sub) a.push("--subdiv", sub)
    return a
  }

  Process {
    id: holidayFetcher
    command: calendarPopup.holidayArgs()
    onExited: (code) => {
      if (code === 0) {
        calendarPopup.fetchFailed = false
        holidaysFile.reload()
      } else {
        calendarPopup.fetchFailed = true
      }
    }
  }

  QtObject {
    id: holidayLoader
    function ensureLoaded() {
      if (calendarPopup.holidaysEnabled && !calendarPopup.fetchFailed) {
        holidaysFile.reload()
      }
    }
  }

  // re-fetch whenever the visible year changes and cache isn't there yet
  onCachePathChanged: {
    calendarPopup.fetchFailed = false
    if (shown && holidaysEnabled) holidaysFile.reload()
  }

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
          if (calendarPopup.viewMonth === 0) {
            calendarPopup.viewMonth = 11
            calendarPopup.viewYear -= 1
          } else {
            calendarPopup.viewMonth -= 1
          }
        }
      }
    }

    Item { Layout.fillWidth: true }
    Text {
      text: calendarPopup.monthNames[calendarPopup.viewMonth] + " " + calendarPopup.viewYear
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
          if (calendarPopup.viewMonth === 11) {
            calendarPopup.viewMonth = 0
            calendarPopup.viewYear += 1
          } else {
            calendarPopup.viewMonth += 1
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
      model: calendarPopup.dayNames
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
      model: calendarPopup.firstDayOfMonth(calendarPopup.viewYear, calendarPopup.viewMonth)
      Item { width: 26 * box.dpi; height: 22 * box.dpi }
    }
    Repeater {
      model: calendarPopup.daysInMonth(calendarPopup.viewYear, calendarPopup.viewMonth)
      delegate: Rectangle {
        id: dayCell
        width: 26 * box.dpi; height: 22 * box.dpi; radius: 6 * box.dpi
        property bool isToday: {
          var today = new Date()
          return index + 1 === today.getDate()
            && calendarPopup.viewMonth === today.getMonth()
            && calendarPopup.viewYear === today.getFullYear()
        }
        property string holidayKey: `${calendarPopup.viewYear}-${calendarPopup.viewMonth + 1}-${index + 1}`
        property string holidayName: calendarPopup.holidays[holidayKey] || ""
        property bool isHoliday: holidayName !== ""

        color: isToday ? Theme.todayFg : Theme.transparent
        border.color: (!isToday && isHoliday) ? Theme.fg7 : Theme.transparent
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: index + 1
          color: isToday ? Theme.bgD : (isHoliday ? Theme.todayFg : Theme.fg)
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
    color: Theme.calendarBg
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
        ? (calendarPopup.holidays[`${calendarPopup.viewYear}-${calendarPopup.viewMonth + 1}-${calendarPopup.tooltipDay + 1}`] || "")
        : ""
    }
  }
}
