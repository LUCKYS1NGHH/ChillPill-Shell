import Quickshell
import Quickshell.Io
import QtQuick

Text {
  id: clockText

  property string todayEvent: ""
  property string fontFamily: Theme.fontFamily

  FileView {
    id: eventsFile
    path: {
      const year = new Date().getFullYear()
      return Quickshell.env("HOME") + "/.cache/chillpill-shell/events_"
           + Config.country + "_" + year + ".json"
    }
    watchChanges: true
    onLoaded: clockText.parseEvents(text())
    onLoadFailed: clockText.todayEvent = ""
  }

  function parseEvents(jsonText) {
    try {
      const data = JSON.parse(jsonText)
      const d = new Date()
      const todayKey = d.getFullYear() + "-" + (d.getMonth() + 1) + "-" + d.getDate()
      clockText.todayEvent = data[todayKey] || ""
    } catch (e) {
      clockText.todayEvent = ""
    }
  }

  text: Qt.formatDateTime(clock.date, Config.clockFormat)
  color: Theme.fg

  font {
    family: Theme.fontFamily
    weight: 500
    pixelSize: 10 * Config.pillScale
    letterSpacing: -0.5
  }
}
