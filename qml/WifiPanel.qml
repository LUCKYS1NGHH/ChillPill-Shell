import Quickshell
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts
import PillBackend

// Wifi panel, shown inside the cc box (see shell.qml)
// UI pass only: logic and keyboard handling unchanged, style follows Lockscreen.qml
Item {
  id: wifiPanel

  property bool shown: false
  signal closeRequested()               // the host owns open state

  // Keys needs active focus
  focus: shown

  property bool passwordPromptVisible: false
  property string passwordPromptSsid: ""
  property string passwordDraft: ""    // survives list rebuilds

  readonly property color accent: Theme.netConnected
  readonly property color accentHover: Qt.lighter(accent, 1.1)
  readonly property color accentText: Theme.netConnectedFg
  readonly property color accentGlow: Qt.lighter(accent, 1.4)

  property var tetherDevice: Networking.devices.values.find(d => d.type === DeviceType.Wired && d.connected)
  readonly property bool tethered: tetherDevice !== undefined

  readonly property bool linked: WifiController.enabled && WifiController.currentSsid.length > 0
  readonly property bool animating: shown && WifiController.enabled && WifiController.scanning

  // staged reveal: header -> hero -> list -> tether
  property real reveal: shown ? 1 : 0
  Behavior on reveal { NumberAnimation { duration: 460; easing.type: Easing.OutCubic } }
  function stage(i) { return Math.max(0, Math.min(1, reveal * 1.5 - i * 0.2)) }

  // delegates exist only while the panel is up
  property bool listLive: false
  Timer { id: liveOff; interval: 320; onTriggered: wifiPanel.listLive = false }

  function closePrompt() {
    passwordPromptVisible = false
    passwordPromptSsid = ""
    passwordDraft = ""
  }

  // reveal a cut-off row
  function revealGroup(group) {
    if (!group) return
    let target = group.y + group.height - list.height
    if (group.y < list.contentY) target = group.y
    target = Math.max(0, Math.min(target, list.contentHeight - list.height))
    if (Math.abs(target - list.contentY) < 1) return
    scrollAnim.to = target
    scrollAnim.restart()
  }

  // row click + enter-to-connect
  function activate(ssid, connected, savedConnection, secure) {
    if (connected) { WifiController.disconnectCurrent(); return }
    if (savedConnection || !secure) { WifiController.connectToNetwork(ssid); return }
    passwordPromptSsid = ssid
    passwordPromptVisible = true
  }

  // the collapsed (connected) row always sorts first, so "first visible"
  // is just whether it exists
  function firstVisibleIndex() {
    if (list.count === 0)
      return -1
    return wifiPanel.linked ? 1 : 0
  }

  function moveSelection(delta) {
    if (list.count === 0) return
    const start = firstVisibleIndex()
    if (start < 0 || start >= list.count) return
    let i = list.currentIndex < start ? start : list.currentIndex + delta
    i = Math.max(start, Math.min(list.count - 1, i))
    list.currentIndex = i
    revealGroup(list.itemAtIndex(i))
  }

  function activateSelected() {
    if (list.currentIndex < 0) return
    const group = list.itemAtIndex(list.currentIndex)
    if (!group) return
    if (group.rowItem.connected) return  // collapsed row, ignore
    if (group.promptOpen) { closePrompt(); return }
    const row = group.rowItem
    activate(String(row.ssid), row.connected, row.savedConnection, row.secure)
  }

  function openPanel() {
    liveOff.stop()
    listLive = true
    // the Loader is asynchronous, so this can run before the panel is in a
    // window: a focus request now would be dropped
    Qt.callLater(() => wifiPanel.forceActiveFocus())
    if (list.currentIndex < 0) list.currentIndex = firstVisibleIndex()
    if (WifiController.enabled) WifiController.refreshNetworks(true)
  }

  onShownChanged: {
    if (shown) {
      openPanel()
    } else {
      liveOff.restart()
      closePrompt()
    }
  }

  // a Loader can build this already-open, and then shown never "changes"
  Component.onCompleted: if (shown) openPanel()

  // the field has focus while up; take it back after
  onPasswordPromptVisibleChanged: {
    if (shown && !passwordPromptVisible) wifiPanel.forceActiveFocus()
  }

  // keep clicks off the cc below
  MouseArea { anchors.fill: parent; enabled: wifiPanel.shown }

  Keys.onUpPressed: moveSelection(-1)
  Keys.onDownPressed: moveSelection(1)
  Keys.onReturnPressed: activateSelected()
  Keys.onEnterPressed: activateSelected()
  Keys.onEscapePressed: closeRequested()

  // shared bits: Theme only, no dependency on this file's ids

  // header button: panel fill, hairline stroke, hover lift (same feel as the lockscreen pills)
  component HeaderButton: Rectangle {
    id: hb
    property string glyph: ""
    property color tone: Theme.fg4
    property color toneHover: Theme.fg
    property color ring: Theme.fg3
    property bool spinning: false
    signal clicked

    implicitWidth: 25
    implicitHeight: 25
    radius: 15
    color: ma.containsMouse ? Theme.bg3 : Theme.bgD
    opacity: enabled ? 1 : 0.5
    scale: ma.pressed ? 0.92 : (ma.containsMouse ? 1.03 : 1)

    Text {
      id: glyphText
      anchors.centerIn: parent
      text: hb.glyph
      color: ma.containsMouse ? hb.toneHover : hb.tone
      font { family: Theme.nerdFontFamily; pixelSize: 12 }
      Behavior on color { ColorAnimation { duration: 120 } }

      RotationAnimator on rotation {
        from: 0; to: 360
        duration: 900
        loops: Animation.Infinite
        running: hb.spinning
      }
    }

    MouseArea {
      id: ma
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: hb.clicked()
    }
  }

  // on/off switch: monochrome like the lockscreen go button (hi fill, bg knob)
  component Toggle: Rectangle {
    id: tg
    property bool checked: false
    property color onColor: Theme.fg3
    signal toggled

    implicitWidth: 38
    implicitHeight: 20
    radius: 11
    color: checked ? onColor : Theme.toggleOffBg
    scale: tgMa.pressed ? 0.95 : 1

    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on border.color { ColorAnimation { duration: 140 } }
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    Rectangle {
      width: tgMa.pressed ? 14 : 12
      height: 12
      radius: 7
      y: 4
      x: tg.checked ? tg.width - width - 4 : 4
      color: tg.checked ? Theme.bg5 : Theme.fg4
      Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
      Behavior on width { NumberAnimation { duration: 90 } }
      Behavior on color { ColorAnimation { duration: 140 } }
    }

    MouseArea {
      id: tgMa
      anchors.fill: parent
      anchors.margins: -4
      cursorShape: Qt.PointingHandCursor
      onClicked: tg.toggled()
    }
  }

  Item {
    id: content
    anchors.fill: parent

    opacity: wifiPanel.shown ? 1 : 0
    visible: opacity > 0
    y: wifiPanel.shown ? 0 : 14
    Behavior on y { NumberAnimation { duration: 280; easing.type: Easing.OutExpo } }
    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutExpo } }

    ColumnLayout {
      anchors.fill: parent
      spacing: 10

      // header
      RowLayout {
        Layout.fillWidth: true
        spacing: 10
        opacity: wifiPanel.stage(0)
        transform: Translate { y: (1 - wifiPanel.stage(0)) * 8 }

        HeaderButton {
          glyph: "\uf053" // nf-fa-chevron_left
          onClicked: wifiPanel.closeRequested()
        }

        Text {
          text: "Wi-Fi"
          color: Theme.fg
          font { family: Theme.fontFamily; pixelSize: 16 }
        }

        // network count, plain text instead of a badge
        readonly property int visibleNets: list.count - (wifiPanel.linked && list.count > 0 ? 1 : 0)
        Text {
          visible: WifiController.enabled && parent.visibleNets > 0
          text: "(" + parent.visibleNets + ")"
          color: Theme.fg3
          font { family: Theme.fontFamily; pixelSize: 13 }
        }

        Item { Layout.fillWidth: true }

        HeaderButton {
          visible: WifiController.enabled
          glyph: "\uf021" // nf-fa-refresh
          tone: WifiController.scanning ? Theme.fg3 : Theme.fg4
          toneHover: WifiController.scanning ? Theme.fg3 : Theme.fg
          spinning: wifiPanel.animating
          enabled: !WifiController.scanning
          onClicked: WifiController.refreshNetworks(true)
        }

        Toggle {
          checked: WifiController.enabled
          onToggled: WifiController.setEnabled(!WifiController.enabled)
        }
      }

      // current connection: lockscreen-style panel card, avatar-like badge
      Rectangle {
        id: hero
        Layout.fillWidth: true
        Layout.preferredHeight: 53
        radius: 18
        color: Theme.heroBg
        opacity: wifiPanel.stage(1)
        transform: Translate { y: (1 - wifiPanel.stage(1)) * 8 }

        // sonar ring
        Rectangle {
          id: ring
          anchors.centerIn: badge
          width: badge.width
          height: badge.height
          radius: width / 2
          color: "transparent"
          visible: WifiController.busy && wifiPanel.shown
          opacity: 0

          ParallelAnimation {
            running: ring.visible
            loops: Animation.Infinite
            NumberAnimation { target: ring; property: "scale"; from: 1; to: 1.6; duration: 1000; easing.type: Easing.OutCubic }
            NumberAnimation { target: ring; property: "opacity"; from: 0.8; to: 0; duration: 1000; easing.type: Easing.OutCubic }
          }
        }

        Rectangle {
          id: badge
          width: 32; height: 32; radius: 19
          anchors.left: parent.left
          anchors.leftMargin: 12
          anchors.verticalCenter: parent.verticalCenter
          color: Theme.fg4
          scale: wifiPanel.linked ? 1 : 0.94
          Behavior on color { ColorAnimation { duration: 220 } }
          Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

          Text {
            anchors.centerIn: parent
            text: "\uf1eb" // nf-fa-wifi
            color: Theme.bg
            font { family: Theme.nerdFontFamily; pixelSize: 15 }
            Behavior on color { ColorAnimation { duration: 200 } }
          }
        }

        Column {
          id: heroText
          anchors.left: badge.right
          anchors.leftMargin: 14
          anchors.right: heroInfo.left
          anchors.rightMargin: 12
          anchors.verticalCenter: parent.verticalCenter
          spacing: 3

          Text {
            width: parent.width
            text: wifiPanel.linked ? WifiController.currentSsid
                : WifiController.enabled ? "not connected" : "Wi-Fi is off"
            color: Theme.fg
            elide: Text.ElideRight
            font { family: Theme.fontFamily; pixelSize: 12 }
          }

          Text {
            width: parent.width
            text: WifiController.busy ? "connecting\u2026"
                : wifiPanel.linked ? "connected"
                : !WifiController.enabled ? "click the toggle to turn on"
                : WifiController.statusText.length > 0 ? WifiController.statusText
                : "pick your known network below"
            color: (wifiPanel.linked && !WifiController.busy) ? wifiPanel.accent : Theme.fg4
            elide: Text.ElideRight
            font { family: Theme.fontFamily; pixelSize: 10 }
            Behavior on color { ColorAnimation { duration: 200 } }
          }
        }

        // signal on top, band + security stacked under it, all right-aligned
        readonly property int heroSignal: WifiController.currentSignal
        readonly property string heroBand: WifiController.currentFrequency > 0
            ? WifiController.currentFrequency < 3000 ? "2.4" : WifiController.currentFrequency < 5920 ? "5" : "6"
            : ""
        Column {
          id: heroInfo
          visible: wifiPanel.linked && !WifiController.busy
          anchors.right: parent.right
          anchors.rightMargin: 16
          anchors.verticalCenter: parent.verticalCenter
          spacing: 3

          Text {
            visible: hero.heroSignal >= 0
            text: hero.heroSignal + "%"
            color: hero.heroSignal > 55 ? Theme.ok : hero.heroSignal > 30 ? Theme.warnMed : Theme.danger
            font { family: Theme.fontFamily; pixelSize: 12 }
            anchors.right: parent.right
            Behavior on color { ColorAnimation { duration: 200 } }
          }

          Row {
            anchors.right: parent.right
            spacing: 6

            Text {
              visible: hero.heroBand.length > 0
              text: hero.heroBand + "GHz"
              color: Theme.fg4
              font { family: Theme.fontFamily; pixelSize: 10 }
            }

            Text {
              visible: hero.heroBand.length > 0 && WifiController.currentSecurity.length > 0
              text: "\u00b7"
              color: Theme.fg7
              font { family: Theme.fontFamily; pixelSize: 10 }
            }

            Text {
              visible: WifiController.currentSecurity.length > 0
              text: WifiController.currentSecurity
              color: Theme.fg4
              font { family: Theme.fontFamily; pixelSize: 10 }
            }
          }
        }

        Item {
          id: track
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          anchors.leftMargin: 22
          anchors.rightMargin: 22
          anchors.bottomMargin: 5
          height: 2
          clip: true
          visible: WifiController.busy && wifiPanel.shown

          Rectangle {
            id: shimmer
            width: track.width * 0.35
            height: 2
            radius: 1
            color: Qt.alpha(Theme.fg3, 0.8)

            // render thread, so the sweep stays smooth on rebuild
            XAnimator on x {
              running: track.visible
              loops: Animation.Infinite
              from: -shimmer.width
              to: track.width
              duration: 900
              easing.type: Easing.InOutQuad
            }
          }
        }
      }

      // network list
      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        opacity: wifiPanel.stage(2)
        transform: Translate { y: (1 - wifiPanel.stage(2)) * 8 }

        ListView {
          id: list
          anchors.fill: parent
          clip: true
          spacing: 5
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height
          reuseItems: false
          model: (wifiPanel.listLive && WifiController.enabled) ? WifiController.networks : null

          opacity: WifiController.busy ? 0.55 : 1
          Behavior on opacity { NumberAnimation { duration: 150 } }

          displaced: Transition {
            NumberAnimation { properties: "y"; duration: 200; easing.type: Easing.OutExpo }
          }

          onMovementStarted: scrollAnim.stop()
          onCountChanged: {
            if (currentIndex >= count) currentIndex = firstVisibleIndex()
            if (currentIndex < 0 && count > 0 && wifiPanel.shown) currentIndex = firstVisibleIndex()
          }

          delegate: Item {
            id: netGroup
            required property int index
            required property var model
            width: list.width
            // the connected row collapses to nothing: it already lives in the
            // hero card above, and a collapsed row keeps layout/clicks sane
            height: model.connected ? 0
                : netRow.height + (netPrompt.height > 0 ? netPrompt.height + 4 : 0)
            visible: !model.connected

            // the row itself, so callers ignore child order
            readonly property var rowItem: netRow

            readonly property bool promptOpen: wifiPanel.passwordPromptVisible
                                                 && wifiPanel.passwordPromptSsid.length > 0
                                                 && wifiPanel.passwordPromptSsid === netRow.ssid

            function restorePrompt() {
              if (!promptOpen) return
              netPrompt.setText(wifiPanel.passwordDraft)
              netPrompt.focusField()
            }
            Component.onCompleted: restorePrompt()
            ListView.onReused: restorePrompt()

            WifiNetworkItem {
              id: netRow

              // "signal" is a qml keyword, hence model
              ssid: model.ssid
              displayName: model.displayName
              signalStrength: model.signal
              secure: model.secure
              savedConnection: model.savedConnection
              connected: model.connected
              selected: netGroup.index === list.currentIndex

              width: parent.width

              onActivated: {
                if (netGroup.promptOpen) {
                  wifiPanel.closePrompt()
                  return
                }
                wifiPanel.activate(netRow.ssid, netRow.connected, netRow.savedConnection, netRow.secure)
              }
            }

            WifiPasswordPrompt {
              id: netPrompt
              x: 8
              y: netRow.height + 4
              width: parent.width - 16
              accent: wifiPanel.accent
              shown: netGroup.promptOpen
              ssid: netRow.ssid

              // geometry is final after the grow anim
              onOpened: {
                netPrompt.focusField()
                wifiPanel.revealGroup(netGroup)
              }

              onEdited: (text) => wifiPanel.passwordDraft = text

              onSubmitted: (password) => {
                WifiController.connectToNetwork(netRow.ssid, password)
                wifiPanel.closePrompt()
              }

              onCancelled: wifiPanel.closePrompt()
            }
          }
        }

        // scan end resets the model, ListView jumps to top
        Connections {
          target: WifiController.networks
          ignoreUnknownSignals: true
          function onModelAboutToBeReset() { restoreView.savedY = list.contentY }
          function onModelReset() { restoreView.restart() }
        }

        Timer {
          id: restoreView
          property real savedY: 0
          interval: 16 // let delegates lay out
          onTriggered: {
            scrollAnim.stop()
            list.contentY = Math.max(0, Math.min(savedY, list.contentHeight - list.height))
          }
        }

        NumberAnimation {
          id: scrollAnim
          target: list
          property: "contentY"
          duration: 220
          easing.type: Easing.OutExpo
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

        // empty state
        Column {
          anchors.centerIn: parent
          spacing: 8
          visible: list.count === 0

          Text {
            id: emptyGlyph
            anchors.horizontalCenter: parent.horizontalCenter
            text: "\uf1eb"
            color: Theme.fg7
            font { family: Theme.nerdFontFamily; pixelSize: 26 }

            SequentialAnimation on opacity {
              running: wifiPanel.animating && emptyGlyph.visible
              loops: Animation.Infinite
              onRunningChanged: if (!running) emptyGlyph.opacity = 1
              NumberAnimation { to: 0.35; duration: 600; easing.type: Easing.InOutSine }
              NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
            }
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: !WifiController.enabled ? "smoke signals only"
                : WifiController.scanning ? "sniffing the air.."
                : wifiPanel.linked ? "connected up top"
                : "nothing out there. touch grass"
            color: Theme.fg4
            font { family: Theme.fontFamily; pixelSize: 12 }
          }
        }
      }

      // error chip
      Rectangle {
        id: errChip
        readonly property bool open: WifiController.errorMessage.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: open ? errText.implicitHeight + 14 : 0
        visible: Layout.preferredHeight > 0.5
        clip: true
        radius: 14
        color: Theme.bgD
        opacity: open ? 1 : 0

        Behavior on Layout.preferredHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 180 } }

        Text {
          id: errIcon
          anchors.left: parent.left
          anchors.leftMargin: 12
          anchors.verticalCenter: parent.verticalCenter
          text: "\uf071" // nf-fa-warning
          color: Theme.warning
          font { family: Theme.nerdFontFamily; pixelSize: 11 }
        }

        Text {
          id: errText
          anchors.left: errIcon.right
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: 8
          anchors.rightMargin: 12
          text: WifiController.errorMessage
          color: Theme.warning
          wrapMode: Text.Wrap
          maximumLineCount: 2
          elide: Text.ElideRight
          font { family: Theme.fontFamily; pixelSize: 10 }
        }
      }

      // usb tethering: lockscreen-style pill
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 38
        radius: 14
        color: Theme.bg
        opacity: wifiPanel.stage(3)
        transform: Translate { y: (1 - wifiPanel.stage(3)) * 8 }

        Text {
          id: usbIcon
          anchors.left: parent.left
          anchors.leftMargin: 16
          anchors.verticalCenter: parent.verticalCenter
          text: "\uf287" // nf-fa-usb
          font { family: Theme.nerdFontFamily; pixelSize: 12 }
          color: wifiPanel.tethered ? wifiPanel.accent : Theme.fg5
          Behavior on color { ColorAnimation { duration: 200 } }
        }

        Text {
          anchors.left: usbIcon.right
          anchors.leftMargin: 14
          anchors.right: parent.right
          anchors.rightMargin: 16
          anchors.verticalCenter: parent.verticalCenter
          text: wifiPanel.tethered ? (wifiPanel.tetherDevice.name || "USB tethering \u00b7 connected") : "USB tethering \u00b7 not connected"
          color: wifiPanel.tethered ? Theme.fg : Theme.fg4
          elide: Text.ElideRight
          font { family: Theme.fontFamily; pixelSize: 10 }
          Behavior on color { ColorAnimation { duration: 200 } }
        }
      }
    }
  }
}
