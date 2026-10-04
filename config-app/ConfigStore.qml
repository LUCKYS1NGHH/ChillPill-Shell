pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string configPath: Quickshell.env("HOME") + "/.config/chillpill-shell/config.jsonc"

    property var cfg: ({})
    property bool loaded: false
    property string status: ""
    property bool statusError: false
    property string lastWritten: ""

    function get(key, fallback) {
        return root.cfg[key] === undefined ? fallback : root.cfg[key]
    }

    function set(key, value) {
        var c = Object.assign({}, root.cfg)
        c[key] = value
        root.cfg = c
        saveTimer.restart()
    }

    function setStatus(msg, isError) {
        root.status = msg
        root.statusError = isError === true
    }

    function reload() { file.reload() }

    FileView {
        id: file
        path: root.configPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            var t = text()
            if (t === root.lastWritten) return
            try {
                root.cfg = JSON.parse(t)
                root.setStatus("Loaded")
            } catch (e) {
                root.setStatus("Parse error: " + e, true)
                return
            }
            root.loaded = true
            statusTimer.restart()
        }
        onLoadFailed: {
            root.loaded = true
            root.setStatus("No config found, will create one")
        }
        onSaved: { root.setStatus("Saved"); statusTimer.restart() }
        onSaveFailed: root.setStatus("Save failed", true)
    }

    Timer {
        id: saveTimer
        interval: 400
        onTriggered: {
            var s = JSON.stringify(root.cfg, null, 2) + "\n"
            root.lastWritten = s
            file.setText(s)
        }
    }
    Timer { id: statusTimer; interval: 2500; onTriggered: root.status = "" }
}
