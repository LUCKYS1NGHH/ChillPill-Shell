import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../components"
import ".."

Page {
    id: pg

    readonly property string hyprFile: Quickshell.env("HOME") + "/.config/hypr/hyprland.lua"
    property string msg: ""
    property bool msgOk: false
    property string out: ""
    property string err: ""
    property bool copied: false
    property var stateList: []

    readonly property string numbers: Array.from({length: pg.block.split("\n").length}, (_, i) => i + 1).join("\n")

    function esc(s) {
        return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/\n/g, "<br/>")
    }

    function hl(code) {
        var out = "", last = 0, m
        var re = /("(?:[^"\\]|\\.)*")|(--[^\n]*)/g
        while ((m = re.exec(code))) {
            out += pg.esc(code.slice(last, m.index))
            if (m[1]) out += '<span style="color:#92de80;">' + pg.esc(m[1]) + "</span>"
            else out += '<span style="color:#555753;">' + pg.esc(m[2]) + "</span>"
            last = m.index + m[0].length
        }
        out += pg.esc(code.slice(last))
        out = out.replace(/\b(hl\.bind|hl\.dsp\.exec_cmd|hl\.on)\b/g, '<span style="color:#dbc970;">$1</span>')
        out = out.replace(/\b(mainMod)\b/g, '<span style="color:#7ba9dc;">$1</span>')
        return out
    }

    function copyBlock() {
        copyProc.command = ["bash", "-c", "printf %s '" + pg.block.replace(/'/g, "'\\''") + "' | wl-copy"]
        copyProc.running = false
        copyProc.running = true
        pg.copied = true
        copyTimer.restart()
    }

    // single source of truth for the managed block; mainMod must exist in hyprland.lua
    readonly property string block:
        "-- >>> chillpill-shell keybinds (managed)\n" +
        "hl.bind(mainMod .. \" + CTRL + C\",  hl.dsp.exec_cmd(\"qs ipc -p /usr/share/chillpill-shell call controlCenter toggle\"))\n" +
        "hl.bind(mainMod .. \" + CTRL + V\",  hl.dsp.exec_cmd(\"qs ipc -p /usr/share/chillpill-shell call cliphist toggle\"))\n" +
        "hl.bind(mainMod .. \" + CTRL + B\",  hl.dsp.exec_cmd(\"qs ipc -p /usr/share/chillpill-shell call miniDashboard toggle\"))\n" +
        "hl.bind(mainMod .. \" + D\", hl.dsp.exec_cmd(\"qs ipc -p /usr/share/chillpill-shell call spotlight toggle\"))\n" +
        "hl.bind(mainMod .. \" + W\", hl.dsp.exec_cmd(\"qs ipc -p /usr/share/chillpill-shell call wallpaperSwitcher toggle\"))\n" +
        "hl.bind(mainMod .. \" + Escape\", hl.dsp.exec_cmd(\"qs ipc -p /usr/share/chillpill-shell call powerMenu toggle\"))\n" +
        "-- <<< chillpill-shell keybinds"

    function paste() {
        pasteProc.command = ["/usr/bin/python3", "/usr/share/chillpill-shell/scripts/paste_keybinds.py", "paste", pg.block]
        pasteProc.running = false
        pasteProc.running = true
    }

    function remove() {
        pasteProc.command = ["/usr/bin/python3", "/usr/share/chillpill-shell/scripts/paste_keybinds.py", "remove"]
        pasteProc.running = false
        pasteProc.running = true
    }

    function runCheck() {
        checkProc.running = false
        checkProc.running = true
    }

    function parseCheck(t) {
        try {
            var rep = JSON.parse(t)
            var order = ["controlCenter", "cliphist", "miniDashboard", "spotlight", "wallpaperSwitcher", "powerMenu"]
            var arr = []
            for (var i = 0; i < order.length; i++) {
                var s = order[i]
                var r = rep.states[s] || { count: 0, managed: false, combo: "" }
                arr.push({
                    state: s,
                    combo: r.combo === "" ? "-" : r.combo,
                    ok: r.managed && r.count === 1,
                    warn: r.count > 1,
                    note: r.count === 0 ? "missing" : (r.count > 1 ? "duplicate" : (r.managed ? "managed" : "old line"))
                })
            }
            pg.stateList = arr
        } catch (e) { }
    }

    Process {
        id: pasteProc
        running: false
        stdout: StdioCollector { onStreamFinished: pg.out = this.text.trim() }
        stderr: StdioCollector { onStreamFinished: pg.err = this.text.trim() }
        onExited: (code) => {
            pg.msgOk = code === 0
            pg.msg = code === 0 ? pg.out : (pg.err || "Failed to paste keybinds")
            msgTimer.restart()
            if (code === 0) pg.runCheck()
        }
    }
    Process {
        id: checkProc
        running: false
        command: ["/usr/bin/python3", "/usr/share/chillpill-shell/scripts/paste_keybinds.py", "check"]
        stdout: StdioCollector { onStreamFinished: pg.parseCheck(this.text.trim()) }
    }
    Process { id: copyProc; running: false }
    Timer { id: copyTimer; interval: 1500; onTriggered: pg.copied = false }
    Component.onCompleted: pg.runCheck()

    Timer { id: msgTimer; interval: 4000; onTriggered: pg.msg = "" }

    Heading { text: "KEYBINDS" }
    Text {
        text: "Pastes a managed bind block (replaces the old one, never duplicates). mainMod must be defined in your config. Binds activate on \"hyprctl reload\" or restart."
        color: Theme.fg5
        font.family: Theme.fontFamily
        font.pixelSize: 11
        Layout.fillWidth: true
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        Layout.bottomMargin: 8
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        FormBtn { label: "Auto paste keybinds"; primary: true; onClicked: pg.paste() }
        FormBtn { label: "Remove keybinds"; onClicked: pg.remove() }
        Text {
            text: pg.msg
            color: pg.msgOk ? Theme.ok : Theme.deleting
            font.family: Theme.fontFamily
            font.pixelSize: 11
            Layout.fillWidth: true
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        }
    }

    Heading { text: "PILL STATE BINDS" }
    Repeater {
        model: pg.stateList
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text {
                text: modelData.ok ? "\u2713" : (modelData.warn ? "\u26a0" : "\u2715")
                color: modelData.ok ? Theme.ok : (modelData.warn ? Theme.warning : Theme.deleting)
                font.family: Theme.fontFamily
                font.bold: true
            }
            Text {
                text: modelData.state
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 12
                Layout.preferredWidth: 140
            }
            Text {
                text: modelData.combo
                color: Theme.fg4
                font.family: Theme.nerdFontFamily
                font.pixelSize: 10
                Layout.fillWidth: true
            }
            Text {
                text: modelData.note
                color: modelData.ok ? Theme.fg5 : (modelData.warn ? Theme.warning : Theme.deleting)
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }
        }
    }

    Heading { text: "PREVIEW" }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: Math.min(250, 30 + codeRow.height + 16)
        radius: 10
        color: Theme.bgD1
        border.color: Theme.bg3
        Layout.topMargin: 2
        Layout.bottomMargin: 4
        clip: true

        // window-chrome header
        Rectangle {
            id: header
            height: 30
            width: parent.width
            color: Theme.bg3
            topLeftRadius: 12
            topRightRadius: 12
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 15
                anchors.verticalCenter: parent.verticalCenter
                text: hyprFile
                color: Theme.fg2
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 22; height: 22; radius: 5
                color: cm.containsMouse ? Theme.bg5 : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: pg.copied ? "\uf00c" : "\uf0c5"
                    color: pg.copied ? Theme.ok : (cm.containsMouse ? Theme.fg : Theme.fg5)
                    font.family: Theme.nerdFontFamily
                    font.pixelSize: 11
                }
                MouseArea {
                    id: cm
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pg.copyBlock()
                }
            }
        }

        // scrollable code with line-number gutter
        Flickable {
            id: codeFlick
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            contentWidth: Math.max(codeRow.width, codeFlick.width)
            contentHeight: codeRow.height + 18
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Row {
                id: codeRow
                y: 9
                Text {
                    text: pg.numbers
                    color: "#555753"
                    font.family: Theme.nerdFontFamily
                    font.pixelSize: 11
                    leftPadding: 12
                    rightPadding: 12
                }
                Rectangle {
                    width: 1
                    height: codeText.implicitHeight
                    color: Theme.bg3
                }
                Text {
                    id: codeText
                    text: pg.hl(pg.block)
                    color: Theme.fg3
                    font.family: Theme.nerdFontFamily
                    font.pixelSize: 11
                    textFormat: Text.RichText
                }
            }
        }
    }
}
