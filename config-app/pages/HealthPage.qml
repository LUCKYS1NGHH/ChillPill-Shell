import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../components"
import ".."

Page {
    id: pg

    property var deps: []
    property string msg: ""

    readonly property var required: deps.filter(d => d.cat === "required")
    readonly property var optional: deps.filter(d => d.cat === "optional")
    readonly property var runtime: deps.filter(d => d.cat === "runtime")
    readonly property var missing: deps.filter(d => !d.found && d.cat !== "runtime")

    function runCheck() {
        checkProc.command = ["bash", "/usr/share/chillpill-shell/scripts/check-deps.sh"]
        checkProc.running = false
        checkProc.running = true
    }

    function copyText(text) {
        copyProc.command = ["bash", "-c", "printf %s '" + text.replace(/'/g, "'\\''") + "' | wl-copy"]
        copyProc.running = false
        copyProc.running = true
        pg.msg = "Copied to clipboard"
        msgTimer.restart()
    }

    function copyInstallCmd() {
        var names = []
        for (var i = 0; i < pg.missing.length; i++) names.push(pg.missing[i].arch)
        copyText("paru -S " + names.join(" ") || "nothing to install")
    }

    function copyNixCmd() {
        var names = []
        for (var i = 0; i < pg.missing.length; i++) names.push(pg.missing[i].nix)
        copyText(names.join(" ") || "nothing to install")
    }

    Component.onCompleted: {
        runCheck()
    }

    Process { id: checkProc; running: false; stdout: StdioCollector { onStreamFinished: { try { pg.deps = JSON.parse(this.text.trim()) } catch (e) { pg.msg = "Check script failed"; msgTimer.restart() } } } }
    Process { id: execProc; running: false }
    Process { id: copyProc; running: false }

    Timer { id: msgTimer; interval: 2000; onTriggered: pg.msg = "" }

    Heading { text: "DEPENDENCIES" }
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Text {
            text: pg.deps.length === 0 ? "Checking\u2026" : (pg.missing.length === 0 ? "All " + pg.deps.length + " checks passed" : pg.missing.length + " missing")
            color: pg.missing.length === 0 ? Theme.ok : Theme.warning
            font.family: Theme.fontFamily
            font.pixelSize: 12
            Layout.fillWidth: true
        }
        FormBtn { label: "Copy install cmd"; onClicked: pg.copyInstallCmd() }
        FormBtn { label: "Copy NixOS pkgs"; onClicked: pg.copyNixCmd() }
        MiniBtn { label: "\ue8d2"; onClicked: pg.runCheck(); fontSize: 15; rectRadius: 8 }
    }
    Repeater {
        model: pg.required
        DepRow {
            label: modelData.label
            hint: modelData.desc
            archPkg: modelData.arch
            copyCmd: modelData.copyCmd
            found: modelData.found
            cat: modelData.cat
            onCopyRequested: (t) => pg.copyText(t)
        }
    }

    Heading { text: "OPTIONAL" }
    Repeater {
        model: pg.optional
        DepRow {
            label: modelData.label
            hint: modelData.desc
            archPkg: modelData.arch
            copyCmd: modelData.copyCmd
            found: modelData.found
            cat: modelData.cat
            onCopyRequested: (t) => pg.copyText(t)
        }
    }

    Heading { text: "RUNTIME" }
    Repeater {
        model: pg.runtime
        DepRow {
            label: modelData.label
            hint: modelData.desc
            archPkg: modelData.arch
            copyCmd: modelData.copyCmd
            found: modelData.found
            cat: modelData.cat
            onCopyRequested: (t) => pg.copyText(t)
        }
    }

    Heading { text: "SMOKE TEST" }
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        FormBtn { label: "Test notification"; onClicked: { execProc.command = ["bash", "-c", "notify-send ChillPill-Shell 'Test notification'"]; execProc.running = false; execProc.running = true; pg.msg = "Sent"; msgTimer.restart() } }
        Text {
            text: pg.msg
            color: Theme.fg5
            font.family: Theme.fontFamily
            font.pixelSize: 11
            Layout.fillWidth: true
        }
    }
}
