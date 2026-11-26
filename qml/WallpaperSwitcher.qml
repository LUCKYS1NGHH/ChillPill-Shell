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

  // delete flow: Delete key -> confirm prompt in a bottom corner
  property string pendingDeletePath: ""
  property string pendingDeleteName: ""
  property int confirmIndex: 0      // 0: cancel, 1: delete
  property int hoveredButton: -1    // mouse hover, cosmetic only
  readonly property bool promptOnRight: true
  readonly property int promptMargin: 16
  property string promptPath: ""    // what the card displays; survives the fade-out
  property string promptName: ""

  onShownChanged: {
    if (shown && wallpaperModel.status === FolderListModel.Ready) {
      wallGrid.currentIndex = 0
      wallGrid.forceActiveFocus()
    }
    if (!shown) { pendingDeletePath = ""; pendingDeleteName = "" }
  }

  color: Theme.bgD
  radius: 18
  visible: opacity > 0
  opacity: shown ? 1 : 0
  Behavior on opacity { NumberAnimation { duration: 225; easing.type: Easing.OutExpo } }
  scale: shown ? 1 : 0.96
  Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
  transformOrigin: Item.Center
  signal closeRequested()

  readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/chillpill-shell"

  function applyWallpaper(path) {
    wallpaperPopup.selectedWallpaper = "file://" + path
    shellRoot.applyWallpaper(path)
  }

  function activateCurrent() {
    var path = wallpaperModel.get(wallGrid.currentIndex, "filePath")
    if (path) applyWallpaper(path)
    if (Config.wsCloseOnWallpaperSet) closeRequested()
  }

  function requestDelete() {
    var idx = wallGrid.hoverIdx !== -1 ? wallGrid.hoverIdx : wallGrid.currentIndex
    var path = wallpaperModel.get(idx, "filePath")
    if (!path) return
    pendingDeleteName = wallpaperModel.get(idx, "fileName")
    pendingDeletePath = path
    promptName = pendingDeleteName
    promptPath = path
    confirmIndex = 0
    hoveredButton = -1
  }

  function cancelDelete() {
    pendingDeletePath = ""
    pendingDeleteName = ""
    hoveredButton = -1
    wallGrid.forceActiveFocus()
  }

  function confirmDelete() {
    var p = pendingDeletePath
    Quickshell.execDetached(["sh", "-c",
      'gio trash -- "$1" 2>/dev/null || trash-put -- "$1" 2>/dev/null || rm -f -- "$1"', "_", p])
    wallGrid.hoverIdx = -1
    cancelDelete()
  }

  function enterPressed() {
    if (pendingDeletePath !== "") {
      if (confirmIndex === 1) confirmDelete()
      else cancelDelete()
    } else {
      activateCurrent()
    }
  }

  Process {
    id: awwwCheck
    command: ["sh", "-c", "command -v awww"]
    running: true
    onExited: (code) => { wallpaperPopup.awwwMissing = (code !== 0 && Config.customWallpaperScript === "") }
  }

  Process {
    id: cwsCheck
    property string targetBin: {
      let trimmed = Config.customWallpaperScript.trim()
      let match = trimmed.match(/^"([^"]+)"|^'([^']+)'|^(\S+)/)
      let bin = match ? (match[1] || match[2] || match[3] || "") : ""
      return bin.replace(/^~/, Quickshell.env("HOME") || "")
    }
    command: ["sh", "-c", "command -v \"$1\" >/dev/null 2>&1 || test -f \"$1\"", "_", targetBin]
    running: targetBin !== ""
    onExited: (code) => { wallpaperPopup.cwsMissing = (targetBin !== "" && code !== 0) }
    onTargetBinChanged: {
      if (targetBin === "") wallpaperPopup.cwsMissing = false
      else { running = false; running = true }
    }
  }

  FolderListModel {
    id: wallpaperModel
    folder: "file://" + Config.wallpapersDir.replace("~", Quickshell.env("HOME"))
    nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp"]
    showDirs: false
    showHidden: false
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

    Text {
      visible: wallpaperPopup.cwsMissing
      Layout.alignment: Qt.AlignHCenter
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
      color: Theme.warning
      text: "Custom wallpaper script/command not found\nMake sure '" + (cwsCheck.targetBin || Config.customWallpaperScript.trim()) + "' exists"
      font { family: Theme.fontFamily; pixelSize: 11 }
    }

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
      property int hoverIdx: -1

      Keys.onEscapePressed: {
        if (wallpaperPopup.pendingDeletePath !== "") wallpaperPopup.cancelDelete()
        else wallpaperPopup.closeRequested()
      }
      Keys.onReturnPressed: wallpaperPopup.enterPressed()
      Keys.onEnterPressed: wallpaperPopup.enterPressed()

      Keys.onPressed: (event) => {
        if (wallpaperPopup.pendingDeletePath !== "") {
          if (event.key === Qt.Key_Left || event.key === Qt.Key_Right || event.key === Qt.Key_Tab)
            wallpaperPopup.confirmIndex = wallpaperPopup.confirmIndex === 0 ? 1 : 0
          else if (event.key === Qt.Key_Space) wallpaperPopup.enterPressed()
          else if (event.key === Qt.Key_Y) wallpaperPopup.confirmDelete()
          else if (event.key === Qt.Key_N) wallpaperPopup.cancelDelete()
          event.accepted = true
          return
        }
        if (event.key === Qt.Key_Delete) {
          if (!event.isAutoRepeat) wallpaperPopup.requestDelete()
          event.accepted = true
          return
        }
        hoverIdx = -1
        if (event.key === Qt.Key_Period || ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_H)) {
          wallpaperModel.showHidden = !wallpaperModel.showHidden
          event.accepted = true
          return
        }
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
        property bool isPendingDelete: wallpaperPopup.pendingDeletePath !== "" && filePath === wallpaperPopup.pendingDeletePath

        opacity: 0
        scale: 0.4
        transformOrigin: Item.Center

        Component.onCompleted: {
          if (Config.wsAnimation) entryAnim.start()
          else { opacity = 1; scale = 1.0 }
        }

        SequentialAnimation {
          id: entryAnim
          PauseAnimation { duration: cell.distFromCenter * 50 }
          ParallelAnimation {
            NumberAnimation { target: cell; property: "opacity"; to: 1; duration: 250; easing.type: Easing.OutExpo }
            NumberAnimation { target: cell; property: "scale"; to: 1.0; duration: 320; easing.type: Easing.OutBack; easing.overshoot: 0.5 }
          }
        }

        property int columns: 3
        property real rowIdx: Math.floor(index / columns)
        property real colIdx: index % columns
        property real totalRows: Math.ceil(wallGrid.count / columns)
        property real centerRow: (totalRows - 1) / 2
        property real centerCol: (columns - 1) / 2
        property real distFromCenter: Math.sqrt((rowIdx - centerRow) * (rowIdx - centerRow) + (colIdx - centerCol) * (colIdx - centerCol))

        Rectangle {
          id: thumbFrame
          anchors.fill: parent
          anchors.margins: 5
          radius: 10
          color: Theme.bg4
          scale: (mouseArea.containsMouse || cell.isCurrent) ? 1.03 : 1.0
          Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutExpo } }

          ClippingRectangle {
            anchors.fill: parent
            radius: 10
            color: Theme.transparent

            Image {
              anchors.fill: parent
              source: wallUrl
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              cache: true
              sourceSize.width: 200
              sourceSize.height: 150
              onStatusChanged: { if (status === Image.Error) console.log("FAILED:", wallUrl) }
            }

            Rectangle {
              anchors.fill: parent
              color: mouseArea.containsMouse ? Theme.white : Theme.transparent
              opacity: mouseArea.containsMouse ? 0.06 : 0
              Behavior on opacity { NumberAnimation { duration: 115 } }
            }

            Rectangle {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              height: 32
              opacity: (mouseArea.containsMouse || cell.isCurrent) ? 1 : 0
              Behavior on opacity { NumberAnimation { duration: 250 } }
              gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.transparent }
                GradientStop { position: 1.0; color: Theme.fadeBottom }
              }
              Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 8
                text: fileName.replace(/\.[^.]+$/, "")
                color: Theme.white
                elide: Text.ElideMiddle
                font { family: Theme.fontFamily; pixelSize: 9 }
              }
            }

            Rectangle {
              anchors.fill: parent
              radius: 10
              color: Theme.transparent
              border.width: 2
              border.color: Theme.danger
              opacity: cell.isPendingDelete ? 1 : 0
              Behavior on opacity { NumberAnimation { duration: 120 } }
            }
          }
        }

        MouseArea {
          id: mouseArea
          anchors.fill: parent
          enabled: wallpaperPopup.pendingDeletePath === ""
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: wallGrid.hoverIdx = index
          onExited: if (wallGrid.hoverIdx === index) wallGrid.hoverIdx = -1
          onClicked: {
            wallGrid.currentIndex = index
            wallpaperPopup.applyWallpaper(filePath)
            if (Config.wsCloseOnWallpaperSet) closeRequested()
          }
        }
      }
    }
  }

  // delete confirmation: card in a bottom corner
  Rectangle {
    id: deletePrompt
    readonly property bool open: wallpaperPopup.pendingDeletePath !== ""
    z: 20
    anchors.bottom: parent.bottom
    anchors.bottomMargin: wallpaperPopup.promptMargin
    anchors.right: wallpaperPopup.promptOnRight ? parent.right : undefined
    anchors.rightMargin: wallpaperPopup.promptMargin
    anchors.left: wallpaperPopup.promptOnRight ? undefined : parent.left
    anchors.leftMargin: wallpaperPopup.promptMargin
    width: Math.min(249, parent.width - 2 * wallpaperPopup.promptMargin)
    height: promptCol.implicitHeight + 24
    radius: 15
    color: Theme.bg1
    border.color: Theme.borderBg3
    border.width: 1

    opacity: open ? 1 : 0
    visible: opacity > 0
    scale: open ? 1 : 0.94
    transformOrigin: wallpaperPopup.promptOnRight ? Item.BottomRight : Item.BottomLeft
    Behavior on opacity { NumberAnimation { duration: open ? 180 : 120; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: open ? 240 : 140; easing.type: Easing.OutCubic } }
    Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    MouseArea { anchors.fill: parent }

    ColumnLayout {
      id: promptCol
      anchors.fill: parent
      anchors.margins: 12
      spacing: 12

      RowLayout {
        Layout.fillWidth: true
        spacing: 10

        ClippingRectangle {
          implicitWidth: 56
          implicitHeight: 38
          radius: 8
          color: Theme.bg4
          Image {
            anchors.fill: parent
            source: wallpaperPopup.promptPath !== "" ? "file://" + wallpaperPopup.promptPath : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 112
            sourceSize.height: 76
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2
          Text {
            text: "Delete wallpaper?"
            color: Theme.fg
            font { family: Theme.fontFamily; pixelSize: 12; weight: 600 }
          }
          Text {
            Layout.fillWidth: true
            text: wallpaperPopup.promptName
            color: Theme.fg4
            elide: Text.ElideMiddle
            font { family: Theme.fontFamily; pixelSize: 10 }
          }
        }
      }

      RowLayout {
        id: promptButtons
        Layout.fillWidth: true
        spacing: 10
        opacity: open ? 1 : 0
        Behavior on opacity {
          SequentialAnimation {
            PauseAnimation { duration: open ? 70 : 0 }
            NumberAnimation { duration: open ? 170 : 100; easing.type: Easing.OutCubic }
          }
        }

        // Cancel button
        Rectangle {
          readonly property bool active: wallpaperPopup.confirmIndex === 0 || wallpaperPopup.hoveredButton === 0
          Layout.fillWidth: true
          implicitHeight: 27
          radius: 8
          color: active ? Theme.focusBgL : Theme.bg1
          border.color: active ? Theme.borderBgFocus : Theme.borderBg3
          border.width: 1
          scale: cancelMouse.pressed ? 0.94 : (active ? 1.03 : 1.0)
          Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
          Behavior on color { ColorAnimation { duration: 120 } }
          Behavior on border.color { ColorAnimation { duration: 120 } }

          RowLayout {
            anchors.centerIn: parent
            spacing: 4
            Text { text: "\uea76"; color: Theme.fg4; Layout.alignment: Qt.AlignVCenter; Layout.topMargin: 1; font { family: Theme.nerdFontFamily; pixelSize: 11 } }
            Text { text: "Cancel"; color: Theme.fg2; font { family: Theme.fontFamily; pixelSize: 9; weight: 500 } }
          }

          MouseArea {
            id: cancelMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onEntered: wallpaperPopup.hoveredButton = 0
            onExited: if (wallpaperPopup.hoveredButton === 0) wallpaperPopup.hoveredButton = -1
            onClicked: wallpaperPopup.cancelDelete()
          }
        }

        // Delete button
        Rectangle {
          readonly property bool active: wallpaperPopup.confirmIndex === 1 || wallpaperPopup.hoveredButton === 1
          Layout.fillWidth: true
          implicitHeight: 27
          radius: 8
          color: Theme.danger
          opacity: active ? 1.0 : 0.85
          scale: confirmMouse.pressed ? 0.94 : (active ? 1.03 : 1.0)
          Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
          Behavior on opacity { NumberAnimation { duration: 120 } }

          RowLayout {
            anchors.centerIn: parent
            spacing: 4
            Text { text: "\uf00c"; color: Theme.white; Layout.alignment: Qt.AlignVCenter; Layout.topMargin: 1; font { family: Theme.nerdFontFamily; pixelSize: 11 } }
            Text { text: "Delete"; color: Theme.white; font { family: Theme.fontFamily; pixelSize: 9; weight: 600 } }
          }

          MouseArea {
            id: confirmMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onEntered: wallpaperPopup.hoveredButton = 1
            onExited: if (wallpaperPopup.hoveredButton === 1) wallpaperPopup.hoveredButton = -1
            onClicked: wallpaperPopup.confirmDelete()
          }
        }
      }
    }
  }
}
