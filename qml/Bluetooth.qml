import Quickshell
import QtQuick
import QtQuick.Layouts
import IslandBackend

RowLayout {
    id: root
    spacing: 4 * Config.paddingScale

    property string iconFg: "#6791dc"
    property string disconIconFg: "#9ea9bd"

    readonly property bool btEnabled: BluetoothController.enabled
    property bool connected: false
    property string connectedName: ""
    property real connectedSignal: 0

    function refreshConnected() {
        for (var i = 0; i < connFinder.count; i++) {
            var it = connFinder.itemAt(i)
            if (it && it.conn) {
                root.connected = true
                root.connectedName = it.devName
                root.connectedSignal = it.devSignal
                return
            }
        }
        root.connected = false
        root.connectedName = ""
        root.connectedSignal = 0
    }

    function toggleBluetooth() {
      BluetoothController.setEnabled(!BluetoothController.enabled)
    }

    Repeater {
        id: connFinder
        model: BluetoothController.enabled ? BluetoothController.devices : null
        delegate: Item {
            readonly property bool conn: model.connected
            readonly property string devName: model.name
            readonly property real devSignal: model.signal
            onConnChanged: root.refreshConnected()
            Component.onCompleted: root.refreshConnected()
        }
    }

    readonly property string icon: {
        if (!BluetoothController.enabled) return String.fromCodePoint(0xf00b2)
        return String.fromCodePoint(0xf00af) // static "connected" glyph
    }

    Text {
        text: root.icon
        color: root.connected ? root.iconFg : root.disconIconFg
        font {
            family: Theme.nerdFontFamily
            pixelSize: 12 * Config.pillScale
        }
    }

    Text {
        text: {
            if (!BluetoothController.enabled) return "off"
            if (!root.connected) return "N/A"
            return root.connectedName
        }
        color: Theme.fg
        font { family: Theme.fontFamily; pixelSize: 10 * Config.pillScale; weight: 500 }
        elide: Text.ElideRight
        Layout.maximumWidth: 90 * Config.pillScale
    }
}
