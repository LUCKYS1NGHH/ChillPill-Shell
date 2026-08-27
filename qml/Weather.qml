import QtQuick

Item {
  id: root
  signal toggleWeather()

  implicitWidth: row.implicitWidth
  implicitHeight: row.implicitHeight

  property string fg: Theme.fg
  property bool clickable: false

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 5

    Text {
      text: WeatherModule.iconGlyph
      color: clickable ? fg : WeatherModule.iconColor
      font { family: Config.nerdFontFamily; pixelSize: clickable ? 12 : 12 * Config.pillScale }
      anchors.verticalCenter: parent.verticalCenter
    }
    Text {
      text: WeatherModule.loading ? "--" : Math.round(WeatherModule.temp) + "°" + (Config.weatherUnits === "metric" ? "C" : "F")
      color: fg
      font { family: Theme.fontFamily; pixelSize: clickable ? 10 : 10 * Config.pillScale; weight: 400 }
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  MouseArea {
    anchors.fill: clickable ? parent : null
    cursorShape: Qt.PointingHandCursor
    onClicked: { console.log("weather clicked"); root.toggleWeather() }
  }
}
