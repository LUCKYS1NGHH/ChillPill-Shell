import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
  id: root

  // external API (was previously read from enclosing scope)
  property real notifMaxHeight: 300
  property real dpi: 1
  property bool controlCenterOpen: false
  readonly property real listContentHeight: notifList.contentHeight

  height: notifBox.height

  // notifications stack popped header
  Rectangle {
    id: headerBar
    anchors.top: notifBox.top
    anchors.topMargin: -20
    anchors.horizontalCenter: parent.horizontalCenter
    width: parent.width - 10
    height: 20
    topLeftRadius: 13
    topRightRadius: 13
    bottomLeftRadius: 0
    bottomRightRadius: 0
    color: Theme.bg5
    visible: notifBox.visible
    z: 0

    Item {
      anchors.fill: parent

      Text {
        text: "Notifications (" + notificationModule.notifications.length + ")"
        color: Theme.fg2
        font { family: Theme.fontFamily; pixelSize: 9; weight: 400 }
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        verticalAlignment: Text.AlignVCenter
      }

      Rectangle {
        width: 60
        height: 16
        radius: 10
        color: clearAllHover.containsMouse ? Theme.bg : Theme.bg1
        Behavior on color { ColorAnimation { duration: 100 } }
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter

        Text {
          text: "Clear all"
          color: Theme.fg3
          font { family: Theme.fontFamily; pixelSize: 8; weight: 400 }
          anchors.centerIn: parent
        }

        MouseArea {
          id: clearAllHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: notificationModule.clearAll()
        }
      }
    }
  }

  // notifications list stack
  Rectangle {
    id: notifBox
    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter
    width: parent.width - 10
    height: Math.min(notifList.contentHeight + 7, root.notifMaxHeight)
    topLeftRadius: 0
    topRightRadius: 0
    bottomLeftRadius: 13
    bottomRightRadius: 13
    color: Theme.bgD
    visible: notificationModule.notifications.length > 0 && root.controlCenterOpen
    clip: true
    border.width: 1
    border.color: Theme.bg2
    z: 1

    Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

    ListView {
      id: notifList
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.topMargin: 5
      anchors.leftMargin: 5
      anchors.rightMargin: 5
      height: Math.min(contentHeight, root.notifMaxHeight)
      spacing: 6
      model: notificationModule.notificationsReversed
      clip: true
      interactive: contentHeight > height
      flickDeceleration: 3000
      maximumFlickVelocity: 2500
      boundsBehavior: Flickable.StopAtBounds

      cacheBuffer: 200
      reuseItems: true

      ScrollBar.vertical: ScrollBar {
        id: notifScrollBar
        policy: ScrollBar.AlwaysOff
        visible: notifList.contentHeight > notifList.height
        width: 10
        anchors.rightMargin: 10
        z: 20
        contentItem: Rectangle {
          implicitWidth: 8
          radius: 10
          color: notifScrollBar.pressed ? "#888"
               : scrollHover.hovered ? "#6f6f6f"
               : "#3a3a3a"
          Behavior on color { ColorAnimation { duration: 100 } }
          HoverHandler { id: scrollHover }
        }
      }

      delegate: Item {
        id: notifDelegate
        width: ListView.view.width
        height: contentColumn.implicitHeight + 7

        Text {
          id: bellIcon
          text: String.fromCodePoint(0xf0f3)
          color: Theme.fg
          font { family: Theme.nerdFontFamily; pixelSize: 16 }
          visible: notifIcon.status !== Image.Ready
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.topMargin: 10
          anchors.leftMargin: 16
        }

        Image {
          id: notifIcon
          width: 22
          height: 22
          fillMode: Image.PreserveAspectFit
          asynchronous: true
          source: {
            if (modelData.image) return modelData.image
            if (modelData.appIcon) {
              return modelData.appIcon.startsWith("/")
                ? "file://" + modelData.appIcon
                : "image://icon/" + modelData.appIcon
            }
            return ""
          }
          enabled: true
          smooth: true
          mipmap: true
          sourceSize: Qt.size(22 * root.dpi, 22 * root.dpi)
          visible: status === Image.Ready
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.topMargin: 10
          anchors.leftMargin: 15
        }

        ColumnLayout {
          id: contentColumn
          anchors.fill: parent
          anchors.leftMargin: 50
          anchors.rightMargin: 3
          anchors.bottomMargin: 20
          spacing: 1

          Item {
            Layout.fillHeight: true
            Layout.topMargin: 8
            visible: !bodyText.visible
          }

          RowLayout {
            Layout.fillWidth: true

            Text {
              text: modelData.summary
              textFormat: Text.PlainText
              color: Theme.fg
              font { family: Theme.fontFamily; pixelSize: 11; weight: 650 }
              elide: Text.ElideRight
              Layout.fillWidth: true
            }

            Text {
              text: modelData.receivedTime ? Qt.formatTime(modelData.receivedTime, "hh:mm") : ""
              color: Theme.fg5
              font { family: Theme.fontFamily; pixelSize: 8 }
              Layout.bottomMargin: 5
            }

            Rectangle {
              Layout.preferredWidth: 22
              Layout.preferredHeight: 22
              radius: 99
              color: dismissHover.containsMouse ? Theme.focusBgL : "transparent"
              Behavior on color { ColorAnimation { duration: 100 } }

              Text {
                text: ""
                color: dismissHover.containsMouse ? Theme.focusFg1 : Theme.fg7
                anchors.centerIn: parent
                font.pixelSize: 11
                Behavior on color { ColorAnimation { duration: 150 } }
              }

              MouseArea {
                id: dismissHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: notificationModule.dismiss(modelData._id)
              }
            }
          }

          Text {
            id: bodyText
            text: modelData.body ? modelData.body.replace(
              /\[([^\]]+)\]\(["']?([^)"']+)["']?\)/g,
              '<a href="$2">$1</a>'
            ) : ""
            textFormat: Text.StyledText
            linkColor: Theme.accent
            color: Theme.fg4
            font { family: Theme.fontFamily; pixelSize: 9; weight: 400 }
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.bottomMargin: 2
            visible: text !== ""
          }

          Item {
            Layout.fillHeight: true
            Layout.bottomMargin: 6
            visible: !bodyText.visible
          }
        }

        Rectangle {
          anchors.bottom: parent.bottom
          width: parent.width
          height: 1
          color: Theme.bg5
          visible: index < notificationModule.notifications.length - 1
        }
      }
    }
  }
}
