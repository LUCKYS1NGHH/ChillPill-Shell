import Quickshell
import QtQuick
import QtQuick.Layouts
import PillBackend

// Bluetooth panel, shown inside the cc box (see shell.qml)
// Same structure as WifiPanel: Item + shown + closeRequested, host owns open state
Item {
  id: btPanel

  property bool shown: false
  signal closeRequested()               // the host owns open state

  // Keys needs active focus
  focus: shown

  readonly property color accent: Theme.netConnected
  readonly property color accentText: Theme.netConnectedFg

  readonly property bool pairing: BluetoothPairingAgent.requestActive

  // filled by the hidden tally Repeater below
  property int connectedCount: 0
  property string connectedName: ""

  readonly property bool linked: BluetoothController.enabled && connectedCount > 0
  readonly property bool animating: shown && BluetoothController.enabled && BluetoothController.scanning

  // staged reveal: header -> hero -> list -> hint
  property real reveal: shown ? 1 : 0
  Behavior on reveal { NumberAnimation { duration: 460; easing.type: Easing.OutCubic } }
  function stage(i) { return Math.max(0, Math.min(1, reveal * 1.5 - i * 0.2)) }

  // footer tip: one random line per open, rotating while it stays up
  readonly property var tips: [
    "right-click or Del to forget a paired device",
    "left-click a device to connect, right-click to forget",
    "the switch up top powers bluetooth off entirely",
    "hit the refresh icon to rescan for nearby gadgets",
    "pairing requests pop up as a prompt right here",
    "connected devices stay pinned at the top of the list"
  ]
  property int tipIndex: Math.floor(Math.random() * tips.length)

  Timer {
    id: tipRotator
    interval: 9000
    repeat: true
    running: btPanel.shown
    onTriggered: btPanel.tipIndex = (btPanel.tipIndex + 1) % btPanel.tips.length
  }

  // delegates exist only while the panel is up
  property bool listLive: false
  Timer { id: liveOff; interval: 320; onTriggered: btPanel.listLive = false }

  // connected device summary for the hero card
  function retally() {
    let n = 0
    let first = ""
    for (let i = 0; i < tally.count; i++) {
      const it = tally.itemAt(i)
      if (it && it.model && it.model.connected) {
        n++
        if (first.length === 0) first = String(it.model.name)
      }
    }
    connectedCount = n
    connectedName = first
  }

  // reveal a cut-off row
  function revealRow(row) {
    if (!row) return
    let target = row.y + row.height - list.height
    if (row.y < list.contentY) target = row.y
    target = Math.max(0, Math.min(target, list.contentHeight - list.height))
    if (Math.abs(target - list.contentY) < 1) return
    scrollAnim.to = target
    scrollAnim.restart()
  }

  // row click + enter: disconnect / connect / pair
  function activate(address, connected, paired) {
    if (BluetoothController.busy || !BluetoothController.enabled) return
    if (connected) { BluetoothController.disconnectDevice(address); return }
    if (paired) { BluetoothController.connectDevice(address); return }
    BluetoothController.pairDevice(address)
  }

  function forget(address, paired) {
    if (BluetoothController.busy || !BluetoothController.enabled) return
    if (paired) BluetoothController.forgetDevice(address)
  }

  function moveSelection(delta) {
    if (list.count === 0) return
    let i = list.currentIndex < 0 ? (delta > 0 ? 0 : list.count - 1) : list.currentIndex + delta
    i = Math.max(0, Math.min(list.count - 1, i))
    list.currentIndex = i
    revealRow(list.itemAtIndex(i))
  }

  function activateSelected() {
    if (pairing) { submitPairing(); return }
    if (list.currentIndex < 0) return
    const row = list.itemAtIndex(list.currentIndex)
    if (!row) return
    activate(String(row.address), row.connected, row.paired)
  }

  function forgetSelected() {
    if (pairing || list.currentIndex < 0) return
    const row = list.itemAtIndex(list.currentIndex)
    if (!row) return
    forget(String(row.address), row.paired)
  }

  // pairing agent: confirm / submit / cancel
  function submitPairing() {
    if (BluetoothPairingAgent.requestRequiresInput) {
      BluetoothPairingAgent.submitSecret(secretField.text)
      secretField.text = ""
    } else if (BluetoothPairingAgent.requestRequiresConfirmation) {
      BluetoothPairingAgent.confirmRequest()
    } else {
      BluetoothPairingAgent.cancelRequest()
    }
  }

  function cancelPairing() {
    if (BluetoothPairingAgent.requestRequiresConfirmation) BluetoothPairingAgent.rejectRequest()
    else BluetoothPairingAgent.cancelRequest()
    secretField.text = ""
  }

  function focusPairing() {
    if (BluetoothPairingAgent.requestRequiresInput) secretField.forceActiveFocus()
    else btPanel.forceActiveFocus()
  }

  function openPanel() {
    liveOff.stop()
    listLive = true
    // the Loader is asynchronous, so this can run before the panel is in a
    // window: a focus request now would be dropped
    Qt.callLater(() => btPanel.forceActiveFocus())
    if (list.currentIndex < 0) list.currentIndex = 0
    if (BluetoothController.enabled) BluetoothController.refreshDevices(true)
  }

  onShownChanged: {
    if (shown) {
      openPanel()
      tipIndex = Math.floor(Math.random() * tips.length)
    } else {
      liveOff.restart()
      secretField.text = ""
    }
  }

  // a Loader can build this already-open, and then shown never "changes"
  Component.onCompleted: if (shown) openPanel()

  // overlay up -> field takes focus, overlay gone -> panel takes it back
  Connections {
    target: BluetoothPairingAgent
    ignoreUnknownSignals: true
    function onRequestActiveChanged() {
      if (!btPanel.shown) return
      if (BluetoothPairingAgent.requestActive) Qt.callLater(btPanel.focusPairing)
      else btPanel.forceActiveFocus()
    }
  }

  // keep clicks off the cc below
  MouseArea { anchors.fill: parent; enabled: btPanel.shown }

  Keys.onUpPressed: moveSelection(-1)
  Keys.onDownPressed: moveSelection(1)
  Keys.onReturnPressed: activateSelected()
  Keys.onEnterPressed: activateSelected()
  Keys.onDeletePressed: forgetSelected()
  Keys.onEscapePressed: {
    if (pairing) cancelPairing()
    else closeRequested()
  }
  Keys.onPressed: (event) => {
    if (event.key === Qt.Key_R && (event.modifiers & Qt.ControlModifier)) {
        BluetoothController.refreshDevices(true)
        event.accepted = true
    }
  }

  // hidden: one item per device, only to know who is connected
  Repeater {
    id: tally
    model: (btPanel.listLive && BluetoothController.enabled) ? BluetoothController.devices : null
    onCountChanged: Qt.callLater(btPanel.retally)

    delegate: Item {
      required property var model
      width: 0; height: 0
      visible: false
      readonly property bool on: model.connected
      onOnChanged: Qt.callLater(btPanel.retally)
      Component.onCompleted: Qt.callLater(btPanel.retally)
      Component.onDestruction: Qt.callLater(btPanel.retally)
    }
  }

  // shared bits: Theme only, no dependency on this file's ids

  // header button: panel fill, hairline stroke, hover lift
  component HeaderButton: Rectangle {
    id: hb
    property string glyph: ""
    property color tone: Theme.fg4
    property color toneHover: Theme.fg
    property bool spinning: false
    signal clicked

    implicitWidth: 25
    implicitHeight: 25
    radius: 15
    color: ma.containsMouse ? Theme.bg3 : Theme.bgD
    opacity: enabled ? 1 : 0.5
    scale: ma.pressed ? 0.92 : (ma.containsMouse ? 1.03 : 1)

    Text {
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

  // on/off switch: monochrome (hi fill, bg knob)
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

  // small pill button for the pairing overlay
  component PillButton: Rectangle {
    id: pb
    property string label: ""
    property bool primary: false
    property color accent: Theme.netConnected
    property color accentText: Theme.netConnectedFg
    signal clicked

    implicitWidth: 84
    implicitHeight: 28
    radius: 14
    color: primary ? (pbMa.containsMouse ? Qt.lighter(accent, 1.1) : accent)
                   : (pbMa.containsMouse ? Theme.bg3 : Theme.bg2)
    scale: pbMa.pressed ? 0.95 : 1

    Behavior on color { ColorAnimation { duration: 100 } }
    Behavior on scale { NumberAnimation { duration: 90 } }

    Text {
      anchors.centerIn: parent
      text: pb.label
      color: pb.primary ? pb.accentText : Theme.fg
      font { family: Theme.fontFamily; pixelSize: 11 }
    }

    MouseArea {
      id: pbMa
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: pb.clicked()
    }
  }

  // one device row
  component DeviceRow: Rectangle {
    id: dr
    property string deviceName: ""
    property bool paired: false
    property bool connected: false
    property real battery: -1
    property bool selected: false
    property bool interactive: true
    property color accent: Theme.netConnected
    signal activated
    signal forgetRequested

    implicitHeight: 42
    radius: 16
    color: selected ? Theme.bg4 : (rowMa.containsMouse ? Theme.bg3 : Theme.rowBg)
    scale: rowMa.pressed ? 0.985 : 1

    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

    Text {
      id: rowGlyph
      anchors.left: parent.left
      anchors.leftMargin: 16
      anchors.verticalCenter: parent.verticalCenter
      text: dr.connected ? "\uf5b0" : dr.paired ? "\uf0c1" : "\uf294"
      color: dr.connected ? dr.accent : Theme.fg4
      font { family: Theme.nerdFontFamily; pixelSize: 12 }
      Behavior on color { ColorAnimation { duration: 200 } }
    }

    Column {
      anchors.left: rowGlyph.right
      anchors.leftMargin: 14
      anchors.right: parent.right
      anchors.rightMargin: 14
      anchors.verticalCenter: parent.verticalCenter
      spacing: 2

      Text {
        width: parent.width
        text: dr.deviceName
        color: Theme.fg
        elide: Text.ElideRight
        font { family: Theme.fontFamily; pixelSize: 11; weight: dr.connected ? 500 : 300 }
      }

      Text {
        width: parent.width
        text: (dr.connected ? "connected" : dr.paired ? "paired" : "not paired")
              + (dr.battery >= 0 ? " \u00b7 " + Math.round(dr.battery) + "%" : "")
        color: dr.connected ? dr.accent : Theme.fg4
        elide: Text.ElideRight
        font { family: Theme.fontFamily; pixelSize: 9 }
        Behavior on color { ColorAnimation { duration: 200 } }
      }
    }

    MouseArea {
      id: rowMa
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      enabled: dr.interactive
      cursorShape: Qt.PointingHandCursor
      onClicked: (mouse) => {
        if (mouse.button === Qt.RightButton) dr.forgetRequested()
        else dr.activated()
      }
    }
  }

  Item {
    id: content
    anchors.fill: parent

    opacity: btPanel.shown ? 1 : 0
    visible: opacity > 0
    y: btPanel.shown ? 0 : 14
    Behavior on y { NumberAnimation { duration: 280; easing.type: Easing.OutExpo } }
    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutExpo } }

    ColumnLayout {
      anchors.fill: parent
      spacing: 10

      // header
      RowLayout {
        Layout.fillWidth: true
        spacing: 10
        opacity: btPanel.stage(0)
        transform: Translate { y: (1 - btPanel.stage(0)) * 8 }

        HeaderButton {
          glyph: "\uf053" // nf-fa-chevron_left
          onClicked: btPanel.closeRequested()
        }

        Text {
          text: "Bluetooth"
          color: Theme.fg
          font { family: Theme.fontFamily; pixelSize: 16 }
        }

        // device count, plain text instead of a badge
        Text {
          visible: BluetoothController.enabled && list.count > 0
          text: "(" + list.count + ")"
          color: Theme.fg3
          font { family: Theme.fontFamily; pixelSize: 13 }
        }

        Item { Layout.fillWidth: true }

        HeaderButton {
          visible: BluetoothController.enabled
          glyph: "\uf021" // nf-fa-refresh
          tone: BluetoothController.scanning ? Theme.fg3 : Theme.fg4
          toneHover: BluetoothController.scanning ? Theme.fg3 : Theme.fg
          spinning: btPanel.animating
          enabled: !BluetoothController.scanning
          onClicked: BluetoothController.refreshDevices(true)
        }

        Toggle {
          checked: BluetoothController.enabled
          onToggled: BluetoothController.setEnabled(!BluetoothController.enabled)
        }
      }

      // current connection: panel card, avatar-like badge
      Rectangle {
        id: hero
        Layout.fillWidth: true
        Layout.preferredHeight: 53
        radius: 18
        color: Theme.heroBg
        opacity: btPanel.stage(1)
        transform: Translate { y: (1 - btPanel.stage(1)) * 8 }

        // sonar ring
        Rectangle {
          id: ring
          anchors.centerIn: badge
          width: badge.width
          height: badge.height
          radius: width / 2
          color: "transparent"
          border.width: 2
          border.color: btPanel.accent
          visible: BluetoothController.busy && btPanel.shown
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
          scale: btPanel.linked ? 1 : 0.94
          Behavior on color { ColorAnimation { duration: 220 } }
          Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

          Text {
            anchors.centerIn: parent
            text: "\uf294" // nf-fa-bluetooth_b
            color: Theme.bg
            font { family: Theme.nerdFontFamily; pixelSize: 15 }
          }
        }

        Column {
          anchors.left: badge.right
          anchors.leftMargin: 14
          anchors.right: parent.right
          anchors.rightMargin: 18
          anchors.verticalCenter: parent.verticalCenter
          spacing: 3

          Text {
            width: parent.width
            text: btPanel.linked
                  ? btPanel.connectedName + (btPanel.connectedCount > 1 ? "  +" + (btPanel.connectedCount - 1) : "")
                  : BluetoothController.enabled ? "no device connected" : "Bluetooth is off"
            color: Theme.fg
            elide: Text.ElideRight
            font { family: Theme.fontFamily; pixelSize: 12 }
          }

          Text {
            width: parent.width
            text: BluetoothController.busy ? "working\u2026"
                : btPanel.linked ? "connected"
                : !BluetoothController.enabled ? "click the toggle to turn on"
                : BluetoothController.scanning ? "looking around\u2026"
                : BluetoothController.adapterName.length > 0 ? "visible as \u201c" + BluetoothController.adapterName + "\u201d"
                : "pick a device below"
            color: (btPanel.linked && !BluetoothController.busy) ? btPanel.accent : Theme.fg4
            elide: Text.ElideRight
            font { family: Theme.fontFamily; pixelSize: 10 }
            Behavior on color { ColorAnimation { duration: 200 } }
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
          visible: BluetoothController.busy && btPanel.shown

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

      // device list
      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        opacity: btPanel.stage(2)
        transform: Translate { y: (1 - btPanel.stage(2)) * 8 }

        ListView {
          id: list
          anchors.fill: parent
          clip: true
          spacing: 5
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height
          reuseItems: true
          // name, address, paired, connected, battery
          model: (btPanel.listLive && BluetoothController.enabled) ? BluetoothController.devices : null

          opacity: BluetoothController.busy ? 0.55 : 1
          Behavior on opacity { NumberAnimation { duration: 150 } }

          displaced: Transition {
            NumberAnimation { properties: "y"; duration: 200; easing.type: Easing.OutExpo }
          }

          onMovementStarted: scrollAnim.stop()
          onCountChanged: {
            if (currentIndex >= count) currentIndex = count - 1
            if (currentIndex < 0 && count > 0 && btPanel.shown) currentIndex = 0
          }

          delegate: DeviceRow {
            id: devRow
            required property int index
            required property var model
            width: list.width

            // so callers ignore child order
            readonly property string address: model.address

            deviceName: model.name
            paired: model.paired
            connected: model.connected
            battery: model.battery
            selected: devRow.index === list.currentIndex
            interactive: !BluetoothController.busy && BluetoothController.enabled
            accent: btPanel.accent

            onActivated: {
              list.currentIndex = devRow.index
              btPanel.activate(devRow.address, devRow.connected, devRow.paired)
            }
            onForgetRequested: btPanel.forget(devRow.address, devRow.paired)
          }
        }

        // scan end resets the model, ListView jumps to top
        Connections {
          target: BluetoothController.devices
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
            text: "\uf293"
            color: Theme.fg7
            font { family: Theme.nerdFontFamily; pixelSize: 26 }

            SequentialAnimation on opacity {
              running: btPanel.animating && emptyGlyph.visible
              loops: Animation.Infinite
              onRunningChanged: if (!running) emptyGlyph.opacity = 1
              NumberAnimation { to: 0.35; duration: 600; easing.type: Easing.InOutSine }
              NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
            }
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: !BluetoothController.enabled ? "radio silence"
                : BluetoothController.scanning ? "listening for beacons.."
                : "no gadgets around. touch grass"
            color: Theme.fg4
            font { family: Theme.fontFamily; pixelSize: 12 }
          }
        }
      }

      // error chip
      Rectangle {
        id: errChip
        readonly property bool open: BluetoothController.errorMessage.length > 0
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
          text: BluetoothController.errorMessage
          color: Theme.warning
          wrapMode: Text.Wrap
          maximumLineCount: 2
          elide: Text.ElideRight
          font { family: Theme.fontFamily; pixelSize: 10 }
        }
      }

      // hint pill, same slot as the wifi usb tether pill
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 38
        radius: 14
        color: Theme.bg
        opacity: btPanel.stage(3)
        transform: Translate { y: (1 - btPanel.stage(3)) * 8 }

        Text {
          id: hintIcon
          anchors.left: parent.left
          anchors.leftMargin: 16
          anchors.verticalCenter: parent.verticalCenter
          text: "\uf400" // nf-fa-light-bulb
          font { family: Theme.nerdFontFamily; pixelSize: 12 }
          color: Theme.fg5
        }

        Text {
          id: tipText
          anchors.left: hintIcon.right
          anchors.leftMargin: 14
          anchors.right: parent.right
          anchors.rightMargin: 16
          anchors.verticalCenter: parent.verticalCenter
          text: btPanel.tips[btPanel.tipIndex]
          color: Theme.fg4
          wrapMode: Text.Wrap
          font { family: Theme.fontFamily; pixelSize: 10 }
        }

        SequentialAnimation {
          id: tipFade
          NumberAnimation { target: tipText; property: "opacity"; to: 0; duration: 140; easing.type: Easing.OutQuad }
          NumberAnimation { target: tipText; property: "opacity"; to: 1; duration: 220; easing.type: Easing.OutCubic }
        }

        Connections {
          target: btPanel
          function onTipIndexChanged() { tipFade.restart() }
        }
      }
    }

    // pairing request overlay, driven entirely by BluetoothPairingAgent
    Rectangle {
      id: pairOverlay
      anchors.fill: parent
      z: 10
      radius: 18
      color: Theme.bgD
      opacity: btPanel.pairing ? 1 : 0
      visible: opacity > 0
      Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

      MouseArea { anchors.fill: parent }

      Column {
        anchors.centerIn: parent
        width: parent.width - 16
        spacing: 12
        y: btPanel.pairing ? 0 : 8

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: BluetoothPairingAgent.promptTitle.length > 0
                  ? BluetoothPairingAgent.promptTitle
                  : ("Pair with " + BluetoothPairingAgent.deviceName)
          color: Theme.fg
          wrapMode: Text.Wrap
          font { family: Theme.fontFamily; pixelSize: 14 }
        }

        Text {
          visible: BluetoothPairingAgent.promptMessage.length > 0
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: BluetoothPairingAgent.promptMessage
          color: Theme.fg4
          wrapMode: Text.Wrap
          font { family: Theme.fontFamily; pixelSize: 11 }
        }

        // agent wants a PIN or passkey typed in (RequestPinCode / RequestPasskey)
        Rectangle {
          visible: BluetoothPairingAgent.requestRequiresInput
          width: parent.width
          height: 36
          radius: 14
          color: Theme.bg
          border.width: 1
          border.color: secretField.activeFocus ? Theme.fg4 : Theme.bg3
          Behavior on border.color { ColorAnimation { duration: 140 } }

          TextInput {
            id: secretField
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            color: Theme.fg
            selectionColor: Theme.fg4
            font { family: Theme.fontFamily; pixelSize: 12 }
            echoMode: TextInput.Normal
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            inputMethodHints: BluetoothPairingAgent.requestNumericInput ? Qt.ImhDigitsOnly : Qt.ImhNone
            validator: BluetoothPairingAgent.requestNumericInput ? intValidator : null
            IntValidator { id: intValidator; bottom: 0 }
            Keys.onReturnPressed: btPanel.submitPairing()
            Keys.onEnterPressed: btPanel.submitPairing()
            Keys.onEscapePressed: btPanel.cancelPairing()
          }
        }

        // agent shows a code (DisplayPinCode / DisplayPasskey / RequestConfirmation)
        Text {
          visible: !BluetoothPairingAgent.requestRequiresInput
                   && BluetoothPairingAgent.displayedCode.length > 0
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: BluetoothPairingAgent.displayedCode
          color: Theme.fg
          font { family: Theme.fontFamily; pixelSize: 22; bold: true; letterSpacing: 3 }
        }

        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: 8

          // Pair / Confirm
          PillButton {
            visible: BluetoothPairingAgent.requestRequiresInput || BluetoothPairingAgent.requestRequiresConfirmation
            primary: true
            accent: btPanel.accent
            accentText: btPanel.accentText
            label: BluetoothPairingAgent.requestRequiresInput ? "Pair" : "Confirm"
            onClicked: btPanel.submitPairing()
          }

          // display-only case: just acknowledge
          PillButton {
            visible: !BluetoothPairingAgent.requestRequiresInput && !BluetoothPairingAgent.requestRequiresConfirmation
            primary: true
            accent: btPanel.accent
            accentText: btPanel.accentText
            label: "OK"
            onClicked: BluetoothPairingAgent.cancelRequest()
          }

          PillButton {
            visible: BluetoothPairingAgent.requestRequiresInput || BluetoothPairingAgent.requestRequiresConfirmation
            label: BluetoothPairingAgent.requestRequiresConfirmation ? "Reject" : "Cancel"
            onClicked: btPanel.cancelPairing()
          }
        }
      }
    }
  }
}
