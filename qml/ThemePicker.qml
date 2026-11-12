import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// theme picker pill state, same language as the bluetooth / control center panels:
// header (back, title + status, reset) -> hairline -> rows with mini desktop previews -> key hint
// fills the pill (320x320, final): fixed margins around, the list takes whatever height is left.
// selection is a single pill that slides between rows (spotlight style), the list scrolls with it.
// keys: up/down or j/k move (wraps), home/end jump, enter/space apply, 1-9 apply directly,
//       r reset, esc close
Item {
  id: root
  implicitWidth: 400
  implicitHeight: 340

  signal closeRequested()
  signal applyRequested(string name)

  readonly property int count: Theme.themeNames.length
  readonly property real rowH: 45
  readonly property real pad: 3          // left / right / bottom edge margin
  readonly property real padTop: 1       // header gets a bit more room under the rounded top
  // selection is tracked by theme NAME, so a rescan / reorder of the list can never
  // make enter or a click apply a different theme than the one highlighted
  property string currentName: ""
  readonly property int current: {
    const i = Theme.themeNames.indexOf(currentName)
    return i < 0 ? 0 : i
  }
  property bool userMoved: false
  property bool applying: false   // one apply per open: ignores key repeat / double click
  property bool kbLock: false     // true while keyboard scrolling, hover must not steal selection

  // staged reveal: header -> list -> hint
  property real reveal: 0
  Behavior on reveal { NumberAnimation { duration: 460; easing.type: Easing.OutCubic } }
  function stage(i) { return Math.max(0, Math.min(1, reveal * 1.5 - i * 0.2)) }

  readonly property string statusLine: count === 0 ? ""
    : (Theme.activeTheme ? Theme.activeTheme : "default") + " \u2022 " + count + (count === 1 ? " preset" : " presets")
  readonly property string hintLine: count > 0
    ? "Enter to apply \u2022 R to reset \u2022 ESC to go back"
    : "ESC to go back"

  function activeIndex() {
    const i = Theme.themeNames.indexOf(Theme.activeTheme)
    return i < 0 ? 0 : i
  }

  // smooth scroll so the row is fully in view (rows are uniform, so y is just index * step)
  function scrollTo(i) {
    const step = rowH + list.spacing
    const y = i * step
    let target = list.contentY
    if (y < list.contentY) target = y
    else if (y + rowH > list.contentY + list.height) target = y + rowH - list.height
    target = Math.max(0, Math.min(target, list.contentHeight - list.height))
    if (Math.abs(target - list.contentY) < 1) return
    scrollAnim.to = target
    scrollAnim.restart()
  }
  // up/down: wraps around like spotlight
  function step(d) {
    if (count === 0) return
    if (applying) return
    userMoved = true
    kbLock = true
    kbLockTimer.restart()
    currentName = Theme.themeNames[(current + d + count) % count]
    scrollTo(current)
  }
  function jumpTo(i) {
    if (count === 0) return
    if (applying) return
    userMoved = true
    kbLock = true
    kbLockTimer.restart()
    currentName = Theme.themeNames[Math.max(0, Math.min(count - 1, i))]
    scrollTo(current)
  }
  function applyName(name) {
    if (applying) return
    applying = true
    applyRequested(name)
    closeTimer.restart()          // close a tick later so the apply is never torn down mid-flight
  }
  function applyAt(i) {
    if (i < 0 || i >= count) return
    applyName(Theme.themeNames[i])
  }
  function resetTheme() { applyName("") }

  Timer { id: closeTimer; interval: 60; onTriggered: { root.closeRequested(); root.applying = false } }
  Timer { id: kbLockTimer; interval: 320; onTriggered: root.kbLock = false }

  // fresh scan every open, so presets dropped into the dir show up without a restart
  Component.onCompleted: {
    Theme.scanThemes()
    currentName = Theme.activeTheme
    reveal = 1
    Qt.callLater(() => { root.forceActiveFocus(); root.scrollTo(root.current) })
  }

  // scan is async: once the list lands, start on the active theme (unless you already moved)
  Connections {
    target: Theme
    function onThemeNamesChanged() {
      if (!root.userMoved) { root.currentName = Theme.activeTheme; Qt.callLater(() => root.scrollTo(root.current)) }
    }
  }

  focus: true
  Keys.enabled: true
  property bool pendingG: false
  Keys.onPressed: (e) => {
    const k = e.key
    e.accepted = true
    if (k !== Qt.Key_G && pendingG) { pendingG = false; gSeqTimer.stop() }
    if (k === Qt.Key_Escape) closeRequested()
    else if (k === Qt.Key_Up   || k === Qt.Key_K) step(-1)
    else if (k === Qt.Key_Down || k === Qt.Key_J) step(1)
    else if (k === Qt.Key_Home) jumpTo(0)
    else if (k === Qt.Key_End) jumpTo(count - 1)
    else if (k === Qt.Key_G && (e.modifiers & Qt.ShiftModifier)) jumpTo(count - 1)
    else if (k === Qt.Key_G && pendingG) { jumpTo(0); pendingG = false; gSeqTimer.stop() }
    else if (k === Qt.Key_G) { pendingG = true; gSeqTimer.restart() }
    else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) applyAt(current)
    else if (k === Qt.Key_R) resetTheme()
    else if (k >= Qt.Key_1 && k <= Qt.Key_9) applyAt(k - Qt.Key_1)
    else e.accepted = false
  }

  Timer {
    id: gSeqTimer
    interval: 600
    onTriggered: root.pendingG = false
  }

  // header button: flat until hovered
  component HeaderButton: Rectangle {
    id: hb
    property string glyph: ""
    property color tone: Theme.fg4
    property color toneHover: Theme.fg
    signal clicked

    implicitWidth: 28
    implicitHeight: 28
    radius: height / 2
    color: ma.containsMouse ? Theme.bg3 : "transparent"
    scale: ma.pressed ? 0.92 : 1

    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

    Text {
      anchors.centerIn: parent
      text: hb.glyph
      color: ma.containsMouse ? hb.toneHover : hb.tone
      font { family: Theme.nerdFontFamily; pixelSize: 12 }
      Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
      id: ma
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: hb.clicked()
    }
  }

  // fills the pill, fixed breathing room on every edge
  ColumnLayout {
    id: content
    anchors.fill: parent
    anchors.leftMargin: root.pad
    anchors.rightMargin: root.pad
    anchors.bottomMargin: root.pad
    anchors.topMargin: root.padTop
    spacing: 8

    // header: back | title + status | reset
    RowLayout {
      Layout.fillWidth: true
      spacing: 8
      opacity: root.stage(0)
      transform: Translate { y: (1 - root.stage(0)) * 8 }

      HeaderButton {
        glyph: "\uf053" // nf-fa-chevron_left
        onClicked: root.closeRequested()
      }

      Column {
        Layout.fillWidth: true
        spacing: 1

        Text {
          text: "Themes"
          color: Theme.fg
          font { family: Theme.fontFamily; pixelSize: 16 }
        }
        Text {
          width: parent.width
          visible: text.length > 0
          text: root.statusLine
          color: Theme.fg4
          elide: Text.ElideRight
          font { family: Theme.fontFamily; pixelSize: 9 }
        }
      }

      HeaderButton {
        glyph: "\uf0e2" // nf-fa-rotate_left (reset to default)
        onClicked: root.resetTheme()
      }
    }

    // hairline divider
    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: 2
      Layout.leftMargin: 4
      Layout.rightMargin: 4
      opacity: root.stage(0)
      Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 1
        color: Theme.bg3
      }
    }

    // preset list: takes all the height between divider and hint
    ListView {
      id: list
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.minimumHeight: 0
      visible: root.count > 0
      clip: true
      spacing: 1
      boundsBehavior: Flickable.StopAtBounds
      interactive: contentHeight > height
      model: Theme.themeNames
      currentIndex: root.current
      highlightFollowsCurrentItem: false
      opacity: root.stage(1)
      transform: Translate { y: (1 - root.stage(1)) * 8 }

      onMovementStarted: scrollAnim.stop()

      NumberAnimation {
        id: scrollAnim
        target: list
        property: "contentY"
        duration: 220
        easing.type: Easing.OutExpo
      }

      // sliding selection pill with a slight overshoot (same feel as spotlight);
      // no slide-in while the panel is still revealing
      highlight: Rectangle {
        x: 2
        y: list.currentItem ? list.currentItem.y : 0
        width: list.width - 4
        height: root.rowH
        radius: 14
        color: Theme.bgD
        opacity: list.currentItem ? 1 : 0
        Behavior on y {
          enabled: root.reveal >= 1
          NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
        }
      }

      delegate: Rectangle {
        id: row
        required property int index
        required property string modelData

        readonly property bool selected: root.current === index
        readonly property bool isActive: Theme.activeTheme === modelData
        property var d: ({})
        readonly property color pvBg: d.bg || Theme.bg
        readonly property color pvFg: d.fg || Theme.fg
        readonly property color pvAccent: d.accent || Theme.accent

        width: list.width
        height: root.rowH
        radius: 14
        color: "transparent"            // the sliding pill does the highlighting
        scale: rowMa.pressed ? 0.985 : 1
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

        FileView {
          id: presetView
          path: Theme.themeDir + "/" + row.modelData + ".json"
          preload: true
          onLoaded: row.refresh()
          onFileChanged: row.refresh()
        }
        function refresh() {
          let o = {}
          try { o = JSON.parse(presetView.text()) } catch (e) { o = {} }
          row.d = o
        }
        Component.onCompleted: refresh()

        // mini "desktop" preview painted in the preset's own colors
        Rectangle {
          id: preview
          width: 30
          height: 25
          radius: 7
          anchors.left: parent.left
          anchors.leftMargin: 11
          anchors.verticalCenter: parent.verticalCenter
          color: row.pvBg
          border.width: 1
          border.color: Qt.rgba(row.pvFg.r, row.pvFg.g, row.pvFg.b, 0.18)
          scale: row.selected ? 1.05 : 1
          Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }

          Rectangle {   // accent pill
            id: pvBar
            x: 5; y: 5
            width: 10; height: 3
            radius: height / 2
            color: row.pvAccent
          }
          Rectangle {   // text line 1
            id: pvLine1
            anchors.left: parent.left
            anchors.leftMargin: 5
            anchors.top: pvBar.bottom
            anchors.topMargin: 4
            width: 14; height: 2
            radius: height / 2
            color: row.pvFg; opacity: 0.6
          }
          Rectangle {   // text line 2
            anchors.left: pvLine1.left
            anchors.top: pvLine1.bottom
            anchors.topMargin: 3
            width: 8; height: 2
            radius: height / 2
            color: row.pvFg; opacity: 0.3
          }
          Rectangle {   // accent dot
            width: 4; height: width
            radius: width / 2
            anchors.right: parent.right
            anchors.rightMargin: 5
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 5
            color: row.pvAccent
          }
        }

        Text {
          id: rowState
          anchors.right: parent.right
          anchors.rightMargin: 14
          anchors.verticalCenter: parent.verticalCenter
          text: (row.d.variant || "") + (row.isActive ? ((row.d.variant ? " \u00b7 " : "") + "active") : "")
          color: row.isActive ? Theme.accent : Theme.fg5
          font { family: Theme.fontFamily; pixelSize: 9 }
        }

        Text {
          anchors.left: preview.right
          anchors.leftMargin: 12 + (row.selected ? 2 : 0)   // nudge selected text right a touch
          anchors.right: rowState.left
          anchors.rightMargin: 10
          anchors.verticalCenter: parent.verticalCenter
          text: row.d.name || row.modelData
          color: row.selected || row.isActive ? Theme.fg : Theme.fg4
          elide: Text.ElideRight
          font { family: Theme.fontFamily; pixelSize: 12; weight: row.isActive ? 500 : 400 }
          Behavior on color { ColorAnimation { duration: 120 } }
          Behavior on anchors.leftMargin { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        }

        MouseArea {
          id: rowMa
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          // hover moves the selection pill, like spotlight
          onEntered: {
            if (root.kbLock || list.moving || scrollAnim.running) return
            root.userMoved = true
            root.currentName = row.modelData
          }
          onClicked: root.applyName(row.modelData)
        }
      }

      // scroll thumb
      Rectangle {
        visible: list.contentHeight > list.height
        width: 3
        radius: 1.5
        anchors.right: parent.right
        y: list.height * list.visibleArea.yPosition
        height: Math.max(16, list.height * list.visibleArea.heightRatio)
        color: Theme.fg4
        opacity: (list.moving || scrollAnim.running) ? 0.7 : 0
        Behavior on opacity { NumberAnimation { duration: 250 } }
      }
    }

    // empty state
    Text {
      visible: root.count === 0
      Layout.fillWidth: true
      Layout.fillHeight: true
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      wrapMode: Text.WordWrap
      text: "No presets around. drop some JSON in\n~/.cache/chillpill-shell/themes/"
      color: Theme.fg4
      font { family: Theme.fontFamily; pixelSize: 10 }
    }

    // key hint: centered, wraps onto a second line instead of clipping
    Text {
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
      maximumLineCount: 2
      text: root.hintLine
      color: Theme.fg4
      font { family: Theme.fontFamily; pixelSize: 10 }
      opacity: root.stage(2)
    }
  }
}
