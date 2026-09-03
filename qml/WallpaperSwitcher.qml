import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel

Rectangle {
  id: wallpaperPopup
  property bool shown: false
  property string selectedWallpaper: ""
  property bool awwwMissing: false
  property bool cwsMissing: false
  anchors.fill: parent

  onShownChanged: {
    if (shown && wallpaperModel.status === FolderListModel.Ready) {
      wallGrid.currentIndex = 0
      wallGrid.forceActiveFocus()
    }
  }

  color: Theme.bgD1
  radius: 18
  visible: opacity > 0
  opacity: shown ? 1 : 0
  Behavior on opacity { NumberAnimation { duration: 225; easing.type: Easing.OutExpo } }
  scale: shown ? 1 : 0.96
  Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
  transformOrigin: Item.Center
  signal closeRequested()

  function applyWallpaper(path) {
    wallpaperPopup.selectedWallpaper = "file://" + path
    if (Config.customWallpaperScript.trim() === "") {
      Quickshell.execDetached(["awww", "img", "--transition-type", "random", path])
    }
    else {
      let script = Config.customWallpaperScript
      let cmd = script.includes("{path}")
          ? script.replace("{path}", "").trim()
          : script + " \"$1\"" // fallback for old-style configs without the placeholder
      Quickshell.execDetached(["sh", "-c", cmd, "_", path])
    }
  }

  function activateCurrent() {
    var path = wallpaperModel.get(wallGrid.currentIndex, "filePath")
    if (path) applyWallpaper(path)
    if (Config.wsCloseOnWallpaperSet) closeRequested()
  }

  // check once whether awww exists on PATH, only if customWallpaperScript is empty string
  Process {
    id: awwwCheck
    command: ["sh", "-c", "command -v awww"]
    running: true
    onExited: (code) => { wallpaperPopup.awwwMissing = (code !== 0 && Config.customWallpaperScript === "") }
  }

  Process {
    id: cwsCheck
    property string resolvedPath: Config.customWallpaperScript
        .replace("{path}", "").trim()
        .replace(/^~/, Quickshell.env("HOME") || "")
    command: ["test", "-f", resolvedPath]
    running: Config.customWallpaperScript.trim() !== ""
    onExited: (code) => { wallpaperPopup.cwsMissing = Config.customWallpaperScript.trim() !== "" && code !== 0 }
  }

  FolderListModel {
    id: wallpaperModel
    folder: "file://" + Config.wallpapersDir.replace("~", Quickshell.env("HOME"))
    nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp"]
    showDirs: false
    caseSensitive: false
    sortField: FolderListModel.Name

    onStatusChanged: {
      if (status === FolderListModel.Ready && wallpaperPopup.shown) {
        wallGrid.currentIndex = 0
        wallGrid.forceActiveFocus()
      }
    }
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 8
    spacing: 15

    // fallback: awww missing
    Text {
      visible: wallpaperPopup.awwwMissing
      Layout.alignment: Qt.AlignHCenter
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
      color: Theme.warning
      text: "awww not found on $PATH\ninstall it to apply wallpapers\nor use your own customWallpaperScript"
      font { family: Theme.fontFamily; pixelSize: 11 }
    }

    // fallback: cws missing
    Text {
      visible: wallpaperPopup.cwsMissing
      Layout.alignment: Qt.AlignHCenter
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
      color: Theme.warning
      text: "Custom wallpaper script not found\nMake sure '" + Config.customWallpaperScript.replace("{path}", "").trim() + "' exists"
      font { family: Theme.fontFamily; pixelSize: 11 }
    }

    // fallback: no wallpapers found
    Text {
      visible: (!wallpaperPopup.awwwMissing && !wallpaperPopup.cwsMissing)
                && wallpaperModel.status === FolderListModel.Ready
                && wallpaperModel.count === 0
      Layout.alignment: Qt.AlignHCenter
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
      color: Theme.warning
      text: "No wallpapers found in\n" + Config.wallpapersDir
      font { family: Theme.fontFamily; pixelSize: 11 }
    }

    GridView {
      id: wallGrid
      visible: (!wallpaperPopup.awwwMissing && !wallpaperPopup.cwsMissing) && wallpaperModel.count > 0
      Layout.fillWidth: true
      Layout.fillHeight: true
      cellWidth: width / 3
      cellHeight: 105
      clip: true
      model: wallpaperModel
      boundsBehavior: Flickable.StopAtBounds
      focus: true
      keyNavigationEnabled: true
      keyNavigationWraps: true
      cacheBuffer: 400
      Keys.onEscapePressed: wallpaperPopup.closeRequested()
      Keys.onReturnPressed: wallpaperPopup.activateCurrent()
      Keys.onEnterPressed: wallpaperPopup.activateCurrent()

      Keys.onPressed: (event) => {
        switch (event.key) {
          case Qt.Key_W: wallGrid.moveCurrentIndexUp();    event.accepted = true; break
          case Qt.Key_S: wallGrid.moveCurrentIndexDown();  event.accepted = true; break
          case Qt.Key_A: wallGrid.moveCurrentIndexLeft();  event.accepted = true; break
          case Qt.Key_D: wallGrid.moveCurrentIndexRight(); event.accepted = true; break
        }
      }

      delegate: Item {
        id: cell
        width: wallGrid.cellWidth
        height: wallGrid.cellHeight
        property string wallUrl: "file://" + filePath
        property bool isCurrent: GridView.isCurrentItem
        property bool isSelected: wallpaperPopup.selectedWallpaper === wallUrl

        property int columns: 3
        property real rowIdx: Math.floor(index / columns)
        property real colIdx: index % columns
        property real totalRows: Math.ceil(wallGrid.count / columns)
        property real centerRow: (totalRows - 1) / 2
        property real centerCol: (columns - 1) / 2
        property real distFromCenter: Math.sqrt((rowIdx - centerRow) * (rowIdx - centerRow) + (colIdx - centerCol) * (colIdx - centerCol))

        opacity: 0
        scale: 0.4
        transformOrigin: Item.Center

        Component.onCompleted: {
          if (Config.wsAnimation) {
            entryAnim.start()
          } else {
            opacity = 1
            scale = 1.0
          }
        }

        SequentialAnimation {
          id: entryAnim
          PauseAnimation { duration: cell.distFromCenter * 50 }
          ParallelAnimation {
            NumberAnimation { target: cell; property: "opacity"; to: 1; duration: 250; easing.type: Easing.OutExpo }
            NumberAnimation { target: cell; property: "scale"; to: 1.0; duration: 320; easing.type: Easing.OutBack; easing.overshoot: 0.5 }
          }
        }

        Rectangle {
          id: thumbFrame
          anchors.fill: parent
          anchors.margins: 5
          radius: 10
          color: Theme.bg4
          scale: (mouseArea.containsMouse || cell.isCurrent) ? 1.03 : 1.0
          Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutExpo } }
          border.width: cell.isCurrent ? 1 : 0
          border.color: Theme.borderBg

          ClippingRectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: 8
            color: "transparent"

            Image {
              anchors.fill: parent
              source: wallUrl
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              cache: true
              sourceSize.width: 200
              sourceSize.height: 150
              onStatusChanged: {
                if (status === Image.Error) console.log("FAILED:", wallUrl)
              }
            }

            Rectangle {
              anchors.fill: parent
              color: mouseArea.containsMouse ? "white" : "transparent"
              opacity: mouseArea.containsMouse ? 0.06 : 0
              Behavior on opacity { NumberAnimation { duration: 115 } }
            }

            // filename shadowed bar
            Rectangle {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              height: 32
              opacity: (mouseArea.containsMouse || cell.isCurrent) ? 1 : 0
              Behavior on opacity { NumberAnimation { duration: 250 } }
              gradient: Gradient {
                GradientStop { position: 0.0; color: "#00000000" }
                GradientStop { position: 1.0; color: "#cc000000" }
              }

              Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 8
                text: fileBaseName
                color: "white"
                elide: Text.ElideMiddle
                font { family: Theme.fontFamily; pixelSize: 9 }
              }
            }
          }
        }

        MouseArea {
          id: mouseArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            wallGrid.currentIndex = index
            wallpaperPopup.applyWallpaper(filePath)
            if (Config.wsCloseOnWallpaperSet) closeRequested()
          }
        }
      }
    }
  }
}
