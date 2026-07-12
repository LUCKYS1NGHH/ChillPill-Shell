import Quickshell
import QtQuick
import QtQuick.Layouts

Rectangle {
  id: weatherPopup

  readonly property color tileBg: "#242424"
  readonly property int tileRadius: 11
  readonly property color dividerColor: "#2a2a2a"
  readonly property color labelText: "#7b7b7b"
  readonly property color valueText: "#dcdcdc"
  readonly property color secondaryText: "#d8d8d8"
  readonly property color headerText: "#c9c9c9"
  readonly property int iconSizeMedium: 13
  readonly property int iconSizeForecast: 16
  readonly property int fontSizeTiny: 8
  readonly property int fontSizeSmall: 9
  readonly property int fontSizeBody: 9
  readonly property int tileSpacing: 8

  property bool shown: false
  visible: opacity > 0.01
  opacity: shown ? 1 : 0
  width: 280
  height: contentCol.implicitHeight + 26
  x: (parent.width - weatherPopup.width) / 2
  y: box.y + box.height + 5
  color: Theme.bg
  radius: 20

  Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutExpo } }

  // column containing city/location and refresh button
  ColumnLayout {
    id: contentCol
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: 14
    spacing: 10

    RowLayout {
      Layout.fillWidth: true

      Text {
        text: Config.weatherLocation
        color: weatherPopup.headerText
        font.family: Theme.fontFamily
        font.pixelSize: 12
        font.weight: 500
        Layout.leftMargin: 3
        Layout.fillWidth: true
        elide: Text.ElideRight
      }

      Text {
        text: "\uead2"
        color: refreshHover.containsMouse ? "#d1d1d1" : "#565656"
        font.family: Config.nerdFontFamily
        font.pixelSize: 13
        Behavior on color { ColorAnimation { duration: 100 } }
        MouseArea {
          id: refreshHover
          anchors.fill: parent
          anchors.margins: -6
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: WeatherModule.refresh()
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 16

      Text {
        text: WeatherModule.iconGlyph
        color: WeatherModule.iconColor
        font.family: Config.nerdFontFamily
        font.pixelSize: 32
        Layout.preferredWidth: 45
        horizontalAlignment: Text.AlignHCenter
      }

      ColumnLayout {
        spacing: 1
        Layout.fillWidth: true
        Text {
          text: WeatherModule.loading ? "..."
              : WeatherModule.errorMessage.length > 0 ? "—"
              : Math.round(WeatherModule.temp) + "°" + (Config.weatherUnits === "metric" ? "C" : "F")
          color: "#ecebeb"
          font.family: Theme.fontFamily
          font.pixelSize: 25
          font.weight: 500
        }
        Text {
          text: WeatherModule.condition
          color: "#7e7e7e"
          font.family: Theme.fontFamily
          font.pixelSize: weatherPopup.fontSizeBody
          font.weight: 400
          visible: !WeatherModule.loading && WeatherModule.errorMessage.length === 0
          elide: Text.ElideRight
          Layout.fillWidth: true
        }
      }
    }

    // stat tiles
    RowLayout {
      Layout.fillWidth: true
      spacing: weatherPopup.tileSpacing
      visible: !WeatherModule.loading && WeatherModule.errorMessage.length === 0

      Repeater {
        model: [
          { icon: "\ue34e", color: "#f18d41", value: Math.round(WeatherModule.feelsLike) + "°", label: "Feels" },
          { icon: "\ue373", color: "#5f99fa", value: WeatherModule.humidity + "%", label: "Humidity" },
          { icon: "\ue34b", color: "#54e04b", value: Math.round(WeatherModule.windSpeed) + " km/h", label: "Wind" }
        ]
        delegate: Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 62
          radius: weatherPopup.tileRadius
          color: statHover.containsMouse ? Qt.lighter(weatherPopup.tileBg, 1.25) : weatherPopup.tileBg
          Behavior on color { ColorAnimation { duration: 120 } }

          MouseArea {
            id: statHover
            anchors.fill: parent
            hoverEnabled: true
          }

          ColumnLayout {
            anchors.centerIn: parent
            spacing: 3

            Text {
              text: modelData.icon
              color: modelData.color
              font.family: Config.nerdFontFamily
              font.pixelSize: weatherPopup.iconSizeMedium
              Layout.alignment: Qt.AlignHCenter
            }

            Text {
              text: modelData.value
              color: weatherPopup.valueText
              font.family: Theme.fontFamily
              font.pixelSize: weatherPopup.fontSizeBody
              font.weight: 600
              Layout.alignment: Qt.AlignHCenter
            }

            Text {
              text: modelData.label
              color: weatherPopup.labelText
              font.family: Theme.fontFamily
              font.pixelSize: weatherPopup.fontSizeTiny
              Layout.alignment: Qt.AlignHCenter
            }
          }
        }
      }
    }

    Rectangle { Layout.fillWidth: true; height: 1; color: weatherPopup.dividerColor }

    // sunrise and sunset
    RowLayout {
      Layout.fillWidth: true
      spacing: 0
      visible: !WeatherModule.loading && WeatherModule.errorMessage.length === 0

      RowLayout {
        spacing: 5

        Text {
          text: "\ue34c"
          color: "#ffcd58"
          font.family: Config.nerdFontFamily
          font.pixelSize: weatherPopup.iconSizeMedium
        }

        Text {
          text: WeatherModule.sunrise
          color: weatherPopup.secondaryText
          font.family: Theme.fontFamily
          font.pixelSize: weatherPopup.fontSizeSmall
        }
      }

      Item { Layout.fillWidth: true }

      RowLayout {
        spacing: 5
        Text {
          text: "\ue34d"
          color: "#ff904d"
          font.family: Config.nerdFontFamily
          font.pixelSize: weatherPopup.iconSizeMedium
        }

        Text {
          text: WeatherModule.sunset
          color: weatherPopup.secondaryText
          font.family: Theme.fontFamily
          font.pixelSize: weatherPopup.fontSizeSmall
        }
      }
    }

    Rectangle { Layout.fillWidth: true; height: 1; color: weatherPopup.dividerColor }

    // forecast
    RowLayout {
      Layout.fillWidth: true
      spacing: weatherPopup.tileSpacing

      Repeater {
        model: WeatherModule.forecast
        delegate: ColumnLayout {
          Layout.fillWidth: true
          spacing: 5

          Text {
            text: Qt.formatDate(new Date(modelData.date), "ddd")
            color: "#6e6e6e"
            font.family: Theme.fontFamily
            font.pixelSize: weatherPopup.fontSizeTiny
            Layout.alignment: Qt.AlignHCenter
          }

          Text {
            text: modelData.iconGlyph
            color: modelData.iconColor
            font.family: Config.nerdFontFamily
            font.pixelSize: weatherPopup.iconSizeForecast
            Layout.alignment: Qt.AlignHCenter
          }

          Text {
            text: Math.round(modelData.maxTemp) + "°/" + Math.round(modelData.minTemp) + "°"
            color: "#a0a0a0"
            font.family: Theme.fontFamily
            font.pixelSize: weatherPopup.fontSizeTiny
            Layout.alignment: Qt.AlignHCenter
          }

        }
      }
    }

    // last time weather updated
    Text {
      text: "Updated at " + Qt.formatTime(WeatherModule.lastUpdated, "hh:mm")
      color: "#8a8a8a"
      font.family: Theme.fontFamily
      font.pixelSize: weatherPopup.fontSizeTiny
      Layout.alignment: Qt.AlignHCenter
      Layout.topMargin: 2
    }
  }
}
