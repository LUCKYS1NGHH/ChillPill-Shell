pragma Singleton
import Quickshell
import QtQuick

Singleton {
  id: root

  // raw payload, kept in both unit systems so that flipping weatherUnits in the
  // config re-renders instantly instead of waiting for the next network fetch
  property var current: ({})
  property var forecastRaw: []
  property int humidity: 0
  property string windDir: ""
  property int uvIndex: 0
  property string condition: ""
  property string weatherCode: ""
  property string iconGlyph: "\ue312"  // weather-cloudy
  property string iconColor: "#9aa0a6"
  property string sunrise: ""
  property string sunset: ""
  property bool loading: false
  property string errorMessage: ""
  property var lastUpdated: new Date()
  property bool hasData: false
  property bool isStale: false
  property bool isError: errorMessage.length > 0 && !isStale

  readonly property bool isMetric: Config.weatherUnits !== "imperial"
  readonly property string tempUnit: isMetric ? "°C" : "°F"
  readonly property string speedUnit: isMetric ? "km/h" : "mph"

  readonly property real temp: pick(current.temp_C, current.temp_F)
  readonly property real feelsLike: pick(current.FeelsLikeC, current.FeelsLikeF)
  readonly property real windSpeed: pick(current.windspeedKmph, current.windspeedMiles)
  readonly property var forecast: forecastRaw.map(day => ({
    date: day.date,
    maxTemp: pick(day.maxtempC, day.maxtempF),
    minTemp: pick(day.mintempC, day.mintempF),
    iconGlyph: day.iconGlyph,
    iconColor: day.iconColor
  }))

  // picks the metric or imperial variant of an API field
  function pick(metricValue, imperialValue) {
    const n = parseFloat(isMetric ? metricValue : imperialValue)
    return isNaN(n) ? 0 : n
  }

  function iconForCode(code) {
    const c = parseInt(code)
    if (c === 113) return { glyph: "\ue30d", color: "#f4c542" }   // sunny day. yellow
    if ([116, 119, 122].includes(c)) return { glyph: "\ue312", color: "#9aa0a6" }  // cloudy, grey
    if ([176, 263, 266, 293, 296, 299, 302, 305, 308, 311, 314, 317, 320, 353, 356, 359].includes(c))
      return { glyph: "\ue318", color: "#4a9de8" }  // rain, blue
    if ([200, 386, 389, 392, 395].includes(c)) return { glyph: "\ue31d", color: "#e8b84a" }  // thunderstorm, amber
    if ([227, 230, 323, 326, 329, 332, 335, 338, 350, 368, 371, 374, 377].includes(c))
      return { glyph: "\ue31a", color: "#d8e8f4" }  // snow, near-white
    if ([143, 248, 260].includes(c)) return { glyph: "\ue313", color: "#8a8a8a" }  // fog, dim grey
    return { glyph: "\ue312", color: "#9aa0a6" }
  }

  function refresh() {
    root.loading = true
    const url = "https://wttr.in/" + encodeURIComponent(Config.weatherLocation) + "?format=j1"
    const xhr = new XMLHttpRequest()
    xhr.onreadystatechange = () => {
      if (xhr.readyState !== XMLHttpRequest.DONE) return
      root.loading = false
      if (xhr.status !== 200) {
        root.errorMessage = "Weather fetch failed."
        root.isStale = root.hasData
        return
      }
      try {
        const data = JSON.parse(xhr.responseText)
        const current = data.current_condition[0]
        const today = data.weather[0]

        root.current = current
        root.humidity = parseInt(current.humidity)
        root.windDir = current.winddir16Point
        root.uvIndex = parseInt(current.uvIndex)
        root.condition = current.weatherDesc[0].value
        root.weatherCode = current.weatherCode

        const iconData = root.iconForCode(current.weatherCode)
        root.iconGlyph = iconData.glyph
        root.iconColor = iconData.color

        root.sunrise = today.astronomy[0].sunrise
        root.sunset = today.astronomy[0].sunset

        root.forecastRaw = data.weather.slice(0, 3).map(day => {
          const dayIcon = root.iconForCode(day.hourly[4].weatherCode)
          return {
            date: day.date,
            maxTempC: day.maxtempC,
            minTempC: day.mintempC,
            maxTempF: day.maxtempF,
            minTempF: day.mintempF,
            iconGlyph: dayIcon.glyph,
            iconColor: dayIcon.color
          }
        })

        root.lastUpdated = new Date()
        root.hasData = true
        root.isStale = false
        root.errorMessage = ""
      } catch (e) {
        root.errorMessage = "Weather parse failed"
        root.isStale = root.hasData
      }
    }
    xhr.open("GET", url)
    xhr.send()
  }

  Timer {
    interval: Config.weatherRefreshInterval
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
}
