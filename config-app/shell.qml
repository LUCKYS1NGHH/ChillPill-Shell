import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// ChillPill Settings — standalone editor for chillpill-shell's config.jsonc

ShellRoot {
    id: root

    readonly property string configPath: Quickshell.env("HOME") + "/.config/chillpill-shell/config.jsonc"

    property var cfg: ({})
    property bool loaded: false
    property string status: ""
    property bool statusError: false
    property string lastWritten: ""

    // Standalone mirror of qml/Theme.qml. The settings app runs as its own
    QtObject {
        id: th

        // more darker (descending)
        readonly property string bg: "#141414"
        readonly property string bg1: "#202020"
        readonly property string bg2: "#222222"
        readonly property string bg3: "#252525"
        readonly property string bg4: "#282828"
        readonly property string bg5: "#323232"
        readonly property string bg6: "#353535"
        readonly property string bg7: "#404040"
        readonly property string bg8: "#454545"
        readonly property string bg9: "#505050"

        readonly property string bgD: "#141414"
        readonly property string bgD1: "#191919"

        // more darker (ascending)
        readonly property string fg: "#dadada"
        readonly property string fg1: "#e7e7e7"
        readonly property string fg2: "#dfdfdf"
        readonly property string fg3: "#c4c4c4"
        readonly property string fg4: "#9e9e9e"
        readonly property string fg5: "#777777"
        readonly property string fg6: "#6a6a6a"
        readonly property string fg7: "#484848"
        readonly property string fg8: "#313131"
        readonly property string fgL: "#e9e9e9"

        // CC sliders
        readonly property string sliderBg: "#c9c9c9"

        readonly property string fg3D: "#a7a7a7"
        readonly property string fg4D: "#c5c4c4" // d == darker

        readonly property string borderBg: "#6a6a6a"
        readonly property string borderBg1: "#484848"
        readonly property string borderBg2: "#323232"
        readonly property string borderBg3: "#282828"
        readonly property string borderBg4: "#242424"
        readonly property string borderBgFocus: "#555555"
        readonly property string borderBgFocus1: "#4f4f4f"

        // focus bg
        readonly property string focusBg: "#282828"
        readonly property string focusBg1: "#2e2e2e"
        readonly property string focusBgD: "#222222"
        readonly property string focusBgL: "#353535" // L == lighter

        readonly property string focusFg: "#d1d1d1"
        readonly property string focusFg1: "#bcbcbc"
        readonly property string focusFg2: "#a8a8a8"

        // live from the file being edited, with the same fallbacks as Config.qml
        readonly property string fontFamily: root.get("textFontFamily", "Monocraft")
        readonly property string nerdFontFamily: root.get("nerdFontFamily", "JetBrainsMono Nerd Font Propo")

        readonly property string warning: "#fac94a"
        readonly property string deleting: "#e32626"

        readonly property string accent: "#979797"
        readonly property string coverArtGlowShadow: "#80aae6" // hardcored for now

        readonly property int fontSizeBase: 13
        readonly property int fontSize: fontSizeBase
    }

    function get(key, fallback) {
        return root.cfg[key] === undefined ? fallback : root.cfg[key]
    }

    function set(key, value) {
        var c = Object.assign({}, root.cfg)
        c[key] = value
        root.cfg = c
        saveTimer.restart()
    }

    // severity rides along with the message; auto-clearing stays with the caller
    function setStatus(msg, isError) {
        root.status = msg
        root.statusError = isError === true
    }

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
            // Missing file: start from empty, first edit creates it
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

    // ───────────────────────── reusable pieces ─────────────────────────

    component MiniBtn: Rectangle {
        id: b
        property string label: ""
        signal clicked()
        width: 28; height: 28; radius: 6
        color: ma.containsMouse ? th.bg8 : th.bg6
        Text { anchors.centerIn: parent; text: b.label; color: th.fg; font.family: th.fontFamily; font.pixelSize: 12 }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: b.clicked()
        }
    }

    component SRow: Rectangle {
        id: r
        property string label: ""
        property string hint: ""
        default property alias content: slot.data
        Layout.fillWidth: true
        implicitHeight: hint ? 62 : 52
        color: "transparent"

        ColumnLayout {
            anchors.left: parent.left
            anchors.right: slot.left
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text { text: r.label; color: th.fg; font.family: th.fontFamily; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight }
            Text { visible: r.hint !== ""; text: r.hint; color: th.fg4; font.family: th.fontFamily; font.pixelSize: 10; Layout.fillWidth: true; elide: Text.ElideRight }
        }
        Item {
            id: slot
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: childrenRect.width
            height: childrenRect.height
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: th.bg3 }
    }

    component ToggleRow: SRow {
        id: t
        property bool value: false
        signal edited(bool v)
        // press-squish: while held, the knob stretches toward the side it will
        // travel to, then slides over on release (classic switch feel)
        Rectangle {
            width: 46; height: 26; radius: 13
            color: t.value ? th.accent : (tMa.containsMouse ? th.bg8 : th.bg6)
            border.width: 1
            border.color: t.value ? "transparent" : th.borderBg3
            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on border.color { ColorAnimation { duration: 140 } }
            Rectangle {
                id: knob
                width: tMa.pressed ? 24 : 20
                height: 20
                radius: knob.width / 2
                y: 3
                x: t.value ? parent.width - knob.width - 3 : 3
                color: th.fgL
                border.width: 1
                border.color: th.borderBg
                Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            }
            MouseArea {
                id: tMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: t.edited(!t.value)
            }
        }
    }

    component NumRow: SRow {
        id: n
        property real value: 0
        property real from: 0
        property real to: 1e9
        property real step: 1
        property real divisor: 1      // display = value / divisor
        property string suffix: ""
        property int decimals: 0
        // live access to the number field, for save handlers
        property alias input: inp
        signal edited(real v)

        function clamp(v) { return Math.max(n.from, Math.min(n.to, v)) }
        function commit(shown) {
            var s = Number(shown)
            if (isNaN(s)) return
            n.edited(n.clamp(Math.round(s * n.divisor)))
        }

        Row {
            spacing: 6
            MiniBtn { label: "−"; onClicked: n.edited(n.clamp(n.value - n.step)) }
            Rectangle {
                width: 84; height: 28; radius: 6; color: th.bg1
                border.color: inp.activeFocus ? th.borderBgFocus : th.borderBg2
                TextInput {
                    id: inp
                    anchors.fill: parent
                    anchors.margins: 6
                    horizontalAlignment: TextInput.AlignHCenter
                    verticalAlignment: TextInput.AlignVCenter
                    color: th.fg
                    font.family: th.fontFamily
                    selectByMouse: true
                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                    text: (n.value / n.divisor).toFixed(n.decimals)
                    onEditingFinished: n.commit(text)
                }
            }
            MiniBtn { label: "+"; onClicked: n.edited(n.clamp(n.value + n.step)) }
            Text {
                visible: n.suffix !== ""
                text: n.suffix
                color: th.fg4
                font.family: th.fontFamily
                width: 28
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    component SliderRow: SRow {
        id: s
        property real value: 0
        property real from: 0
        property real to: 1
        property real step: 0.05
        property int decimals: 2
        signal edited(real v)
        readonly property real frac: Math.max(0, Math.min(1, (value - from) / (to - from)))

        Row {
            spacing: 14
            Item {
                id: track
                width: 200; height: 24
                // mirrors the control center volume/brightness sliders (CcSliders.qml):
                // thin bar, no knob, spring-damped fill, taller hit area than the bar
                Rectangle {
                    id: bar
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width; height: 4; radius: 4; color: th.bg5
                    Rectangle {
                        width: parent.width * s.frac
                        height: parent.height
                        radius: parent.radius
                        color: th.sliderBg
                        Behavior on width {
                            SpringAnimation { spring: 15.5; damping: 1.8; epsilon: 0.40 }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.topMargin: -8; anchors.bottomMargin: -8
                        cursorShape: Qt.PointingHandCursor
                        function upd(mx) {
                            var f = Math.max(0, Math.min(1, mx / bar.width))
                            var v = s.from + f * (s.to - s.from)
                            v = Math.round(v / s.step) * s.step
                            s.edited(Number(v.toFixed(s.decimals)))
                        }
                        onClicked: (mouse) => upd(mouse.x)
                        onPositionChanged: (mouse) => { if (pressed) upd(mouse.x) }
                    }
                }
            }
            Text {
                text: s.value.toFixed(s.decimals)
                color: th.fg
                font.family: th.fontFamily
                font.pixelSize: 10
                width: Math.max(35, implicitWidth)
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    component TextRow: SRow {
        id: tr
        property string value: ""
        property string placeholder: ""
        property int fieldWidth: 280
        // live access to the text field, for save handlers
        property alias input: ti
        signal edited(string v)
        Rectangle {
            width: tr.fieldWidth; height: 32; radius: 6; color: th.bg1
            border.color: ti.activeFocus ? th.borderBgFocus : th.borderBg2
            TextInput {
                id: ti
                anchors.fill: parent
                anchors.margins: 8
                verticalAlignment: TextInput.AlignVCenter
                color: th.fg
                font.family: th.fontFamily
                selectByMouse: true
                clip: true
                text: tr.value
                onEditingFinished: tr.edited(text)
            }
            Text {
                anchors.fill: parent
                anchors.margins: 8
                verticalAlignment: Text.AlignVCenter
                visible: ti.text === "" && !ti.activeFocus
                text: tr.placeholder
                color: th.fg6
                font.family: th.fontFamily
            }
        }
    }

    component ChoiceRow: SRow {
        id: c
        property var options: []
        property string value: ""
        signal edited(string v)
        Row {
            spacing: 4
            Repeater {
                model: c.options
                Rectangle {
                    id: opt
                    required property string modelData
                    width: lbl.implicitWidth + 24; height: 30; radius: 6
                    color: opt.modelData === c.value ? th.accent : (optMa.containsMouse ? th.bg8 : th.bg6)
                    Text {
                        id: lbl
                        anchors.centerIn: parent
                        text: opt.modelData
                        color: opt.modelData === c.value ? th.bgD : th.fg
                        font.family: th.fontFamily
                    }
                    MouseArea {
                        id: optMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: c.edited(opt.modelData)
                    }
                }
            }
        }
    }

    // Square chip control; dim = can't apply right now
    component ChipBtn: Rectangle {
        id: cb
        property string label: ""
        property bool dim: false
        property bool danger: false
        signal clicked()
        // so the parent thumb's hover state includes this control
        readonly property bool hovered: cma.containsMouse

        width: 20; height: 22; radius: 5
        color: cma.containsMouse ? (cb.danger ? th.bgD1 : th.bg6) : "transparent"
        Text {
            anchors.centerIn: parent
            text: cb.label
            color: cb.dim ? th.fg8 : (cb.danger ? th.deleting : th.fg4)
            font.family: th.fontFamily
            font.pixelSize: 11
            Behavior on color { ColorAnimation { duration: 90 } }
        }
        MouseArea {
            id: cma
            anchors.fill: parent
            // disabled drops hover, so the dim button stays bare
            enabled: !cb.dim
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: cb.clicked()
        }
    }

    // Wide text button for the custom module form
    component FormBtn: Rectangle {
        id: fb
        property string label: ""
        property bool primary: false
        signal clicked()

        implicitWidth: lbl.implicitWidth + 26
        height: 28; radius: 6
        color: fb.primary ? th.accent : (fbMa.containsMouse ? th.bg4 : th.bg2)
        Text {
            id: lbl
            anchors.centerIn: parent
            text: fb.label
            color: fb.primary ? th.bgD : (fbMa.containsMouse ? th.fg : th.fg4)
            font.family: th.fontFamily
        }
        MouseArea {
            id: fbMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: fb.clicked()
        }
    }

    component ModuleThumb: Rectangle {
        id: mt

        property string icon: ""
        property string text: ""
        property color iconColor: th.fg
        property bool segments: false
        property int segmentCount: 5
        property int activeSegment: -1
        property bool flag: false
        property color flagColor: th.accent
        property bool editable: false
        property bool removable: false
        property bool pinned: false
        property bool removeState: false
        property real iconSize: 10

        signal clicked()
        signal removeRequested()
        signal editRequested()
        signal dragBegin(real localX, real globalX, real globalY)
        signal dragMove(real globalX, real globalY)
        signal dragEnd(real globalX)

        readonly property real ps: Math.max(0.5, root.get("pillScale", 1))
        readonly property bool hovered: ma.containsMouse || edBtn.hovered || rmBtn.hovered
        readonly property int padR: 0

        implicitWidth: rowOuter.implicitWidth + 4 * mt.ps + mt.padR
        implicitHeight: Math.round(17.5 * mt.ps)
        radius: 13
        color: "transparent"

        Rectangle {
            visible: mt.removeState
            anchors.fill: parent
            radius: parent.radius
            color: "#e2232326"
        }

        RowLayout {
            id: rowOuter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 4 * mt.ps
            anchors.rightMargin: mt.padR
            spacing: 4 * mt.ps

            Rectangle {
                visible: mt.flag
                implicitWidth: 5; implicitHeight: 5; radius: 2.5
                color: mt.flagColor
            }
            Row {
                visible: mt.segments
                spacing: 4 * mt.ps
                Repeater {
                    model: mt.segmentCount
                    Rectangle {
                        id: seg
                        required property int index
                        readonly property bool on: mt.activeSegment === seg.index
                        width: 17.5 * mt.ps; height: 17.5 * mt.ps; radius: 8 * mt.ps
                        color: seg.on ? "#4d5258" : "#393c41"
                        Text {
                            anchors.centerIn: parent
                            text: seg.index + 1
                            color: seg.on ? "#ffffff" : "#b3b9c2"
                            font.family: th.fontFamily
                            font.pixelSize: 9 * mt.ps
                        }
                    }
                }
            }
            Text {
                visible: !mt.segments && mt.icon !== ""
                text: mt.icon
                color: mt.iconColor
                font.family: th.nerdFontFamily
                font.pixelSize: mt.iconSize * mt.ps
            }
            Text {
                visible: !mt.segments && mt.text !== ""
                text: mt.text
                color: th.fg
                font.family: th.fontFamily
                font.pixelSize: 10 * mt.ps
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.OpenHandCursor
            property point pressPt: Qt.point(0, 0)
            property bool dragged: false
            property real lastGX: 0

            // A lost grab (fast move, pointer grabbed by the compositor, cursor
            // leaving the item) clears `pressed` without ever emitting
            // `onReleased`. Without this the drop is never committed and the
            // bar stays wedged in its dragging state forever.
            property bool released: false
            function endDrag() {
                if (!ma.dragged || ma.released) return
                ma.dragged = false
                mt.dragEnd(ma.lastGX)
            }

            onPressed: (m) => {
                ma.pressPt = Qt.point(m.x, m.y)
                ma.dragged = false
                ma.released = false
            }
            onPressedChanged: if (!ma.pressed && ma.dragged) ma.endDrag()
            onPositionChanged: (m) => {
                if (!ma.pressed) return
                var g = mt.mapToGlobal(m.x, m.y)
                ma.lastGX = g.x
                if (!ma.dragged && (Math.abs(m.x - ma.pressPt.x) > 5 || Math.abs(m.y - ma.pressPt.y) > 5)) {
                    ma.dragged = true
                    mt.dragBegin(ma.pressPt.x, g.x, g.y)
                }
                if (ma.dragged) mt.dragMove(g.x, g.y)
            }
            onReleased: (m) => {
                ma.released = true
                if (ma.dragged) {
                    ma.dragged = false
                    mt.dragEnd(mt.mapToGlobal(m.x, 0).x)
                } else mt.clicked()
            }
        }

        Row {
            visible: mt.hovered && !mt.pinned && (mt.editable || mt.removable)
            anchors.right: parent.right
            anchors.rightMargin: 2
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            ChipBtn {
                id: edBtn
                visible: mt.editable
                label: "✎"
                width: 18; height: 18
                onClicked: mt.editRequested()
            }
            ChipBtn {
                id: rmBtn
                visible: mt.removable
                label: "✕"
                width: 18; height: 18
                danger: true
                onClicked: mt.removeRequested()
            }
        }
    }

    component PillBarPreview: Item {
        id: bar
        property var value: []
        property var known: []
        property Item removeArea: null
        signal edited(var v)
        signal editRequested(int slot)
        Layout.fillWidth: true
        implicitHeight: 50

        readonly property int poolSize: 12

        property var disp: []
        property var widths: []
        function syncDisp() {
            var a = []
            for (var i = 0; i < bar.value.length; i++) a.push(bar.value[i])
            var w = bar.widths.slice()
            for (var j = 0; j < bar.poolSize; j++) if (w[j] === undefined) w[j] = 0
            w.length = bar.poolSize
            bar.widths = w
            bar.disp = a
        }
        // A drop that never lands (grab lost, pointer grabbed by the compositor)
        // used to leave dragActive/availActive true, which blocked every
        // subsequent syncDisp and froze the preview. A drag that has not seen a
        // move for this long is treated as abandoned and reset.
        readonly property int dragStaleMs: 400
        property real lastMoveAt: 0

        Timer {
            id: staleWatch
            interval: 120
            repeat: true
            running: bar.dragActive || bar.availActive
            onTriggered: {
                if (!bar.dragActive && !bar.availActive) return
                if (Date.now() - bar.lastMoveAt < bar.dragStaleMs) return
                if (bar.availActive) bar.availEnd()
                else bar.endDrag()
            }
        }

        onValueChanged: if (!bar.dragActive && !bar.availActive) bar.syncDisp()
        Component.onCompleted: bar.syncDisp()

        readonly property real ps: Math.max(0.5, root.get("pillScale", 1))
        readonly property real barH: Math.round(17.5 * bar.ps) + 10
        readonly property real lnGap: 13 * bar.ps
        readonly property real contentInset: 5

        property bool dragActive: false
        property int dragSlot: -1
        property real grabX: 0
        property real dragThumbX: 0
        property bool removeTarget: false
        property var grabbedEntry: null
        property bool availActive: false
        property string availName: ""
        property bool availOver: false
        property int insertAt: -1
        property real ghostX: -999

        function noteWidth(i, w) {
            if (i < 0 || i >= bar.disp.length) return
            var a = bar.widths.slice()
            a[i] = w
            bar.widths = a
        }

        function sample(name) {
            switch (name) {
            case "battery":       return { icon: String.fromCodePoint(0xf0081), color: "#4bd25c", text: "98%" }
            case "volume":        return { icon: String.fromCodePoint(0xf057e), color: th.fg,     text: "64%" }
            case "workspaces":    return { icon: "",       color: th.fg,     text: "", segments: true, n: Math.min(Math.max(root.get("maxWorkspaces", 5), 1), 6) }
            case "network":       return { icon: String.fromCodePoint(0xf0928), color: "#6791dc", text: "Home" }
            case "clock":         return { icon: "",       color: th.fg,     text: Qt.formatTime(new Date(), root.get("clockFormat", "hh:mm")) }
            case "brightness":    return { icon: String.fromCodePoint(0xf00e0), color: th.fg,     text: "84%" }
            case "vpn":           return { icon: String.fromCodePoint(0xf099d), color: "#48cc47", text: "on" }
            case "notifications": return { icon: String.fromCodePoint(0xf0f3),  color: "#e2b052", text: "7" }
            case "bluetooth":     return { icon: String.fromCodePoint(0xf00af), color: "#6591e0", text: "on", iconSize: 13 }
            case "weather":       return { icon: String.fromCodePoint(0xe312),  color: "#d8ad5c", text: "24°C", iconSize: 11 }
            default:              return { icon: String.fromCodePoint(0xf016),  color: th.fg4,    text: name }
            }
        }

        function thumbProps(entry) {
            if (typeof entry === "object" && entry !== null) {
                var base = entry.run ? String(entry.run).split("/").pop() : "custom"
                return {
                    icon: entry.icon || "",
                    color: th.fg,
                    text: base,
                    segments: false, segN: 0, activeSeg: -1,
                    flag: false,
                    editable: true,
                    iconSize: 10
                }
            }
            var s = bar.sample(String(entry))
            var unk = bar.known.indexOf(String(entry)) < 0
            return {
                icon: s.icon, color: s.color, text: s.text,
                segments: s.segments === true, segN: s.n || 0, activeSeg: 0,
                flag: unk, flagColor: th.warning,
                editable: false,
                iconSize: s.iconSize || 10
            }
        }

        Rectangle {
            id: barRect
            width: Math.max(140, bar.groupWidth() + 62 * bar.ps)
            height: bar.barH
            radius: 20 * bar.ps
            color: "#0d0d0d"
            clip: true
            anchors.centerIn: parent

            Item {
                id: content
                anchors.fill: parent
                anchors.margins: bar.contentInset

                Repeater {
                    model: bar.poolSize
                    delegate: ModuleThumb {
                        id: thumb
                        required property int index
                        readonly property bool shown: index < bar.disp.length
                        readonly property bool dragging: bar.dragActive && thumb.index === bar.dragSlot
                        readonly property var props: {
                            if (thumb.dragging && bar.grabbedEntry !== null && bar.grabbedEntry !== undefined)
                                return bar.thumbProps(bar.grabbedEntry)
                            var e = bar.disp[thumb.index]
                            if (e === undefined)
                                return { icon: "", text: "", color: "#00000000", segN: 0, flagColor: "#00000000" }
                            return bar.thumbProps(e)
                        }

                        visible: thumb.shown
                        width: implicitWidth
                        anchors.verticalCenter: parent.verticalCenter
                        x: thumb.dragging ? bar.dragThumbX : bar.thumbX(thumb.index)
                        Behavior on x {
                            enabled: !thumb.dragging
                            NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
                        }
                        z: thumb.dragging ? 10 : 0
                        scale: thumb.dragging ? 1.04 : 1.0

                        icon: props.icon
                        text: props.text
                        iconColor: props.color
                        segments: props.segments === true
                        segmentCount: props.segN
                        activeSegment: props.activeSeg !== undefined ? props.activeSeg : -1
                        flag: props.flag === true
                        flagColor: props.flagColor
                        editable: props.editable === true
                        iconSize: props.iconSize || 10
                        pinned: thumb.dragging
                        removeState: thumb.dragging && bar.removeTarget

                        Component.onCompleted: thumb.shown && bar.noteWidth(thumb.index, thumb.implicitWidth)
                        onImplicitWidthChanged: thumb.shown && bar.noteWidth(thumb.index, thumb.implicitWidth)

                        onClicked: { if (props.editable === true) bar.editRequested(thumb.index) }
                        onEditRequested: bar.editRequested(thumb.index)
                        onDragBegin: (lx, gx, gy) => bar.beginBarDrag(thumb.index, lx, gx, gy)
                        onDragMove: (gx, gy) => { if (!bar.availActive) bar.moveDrag(gx, gy) }
                        onDragEnd: (gx) => { if (!bar.availActive) bar.endDrag() }
                    }
                }

                Rectangle {
                    id: mark
                    visible: (bar.dragActive || bar.availActive) && bar.insertAt >= 0
                    width: 2; radius: 1
                    color: th.fgL
                    x: bar.thumbX(bar.insertAt) - 1
                    y: 2
                    height: parent.height - 4
                }

                ModuleThumb {
                    id: availGhost
                    visible: bar.availActive
                    width: implicitWidth
                    x: bar.ghostX
                    anchors.verticalCenter: parent.verticalCenter
                    z: 20
                    removable: false
                    editable: false
                }

                Text {
                    anchors.centerIn: parent
                    visible: bar.disp.length === 0 && !bar.dragActive && !bar.availActive
                    text: "drag modules here"
                    color: th.fg6
                    font.family: th.fontFamily
                }

                Text {
                    anchors.centerIn: parent
                    visible: bar.disp.length > bar.poolSize
                    text: "only the first " + bar.poolSize + " modules are shown here"
                    color: th.warning
                    font.family: th.fontFamily
                    font.pixelSize: 10
                }
            }
        }

        function groupWidth() {
            var w = 0, n = 0
            for (var k = 0; k < bar.disp.length; k++) {
                if (bar.dragActive && k === bar.dragSlot) continue
                w += bar.widths[k] || 0
                n++
            }
            return w + Math.max(0, n - 1) * bar.lnGap
        }
        function centerOffset() {
            var avail = barRect.width - 2 * bar.contentInset
            return Math.max(0, Math.floor((avail - bar.groupWidth()) / 2))
        }

        function thumbX(i) {
            var acc = bar.centerOffset()
            for (var k = 0; k < i; k++) {
                if (bar.dragActive && k === bar.dragSlot) continue
                acc += (bar.widths[k] || 0) + bar.lnGap
            }
            return acc
        }

        function insertionIndex(cx) {
            var n = bar.disp.length
            var acc = bar.centerOffset()
            for (var d = 0; d < n; d++) {
                if (bar.dragActive && d === bar.dragSlot) continue
                var w = bar.widths[d] || 0
                acc += w / 2
                if (cx <= acc) return d
                acc += w / 2 + bar.lnGap
            }
            return n
        }

        function beginBarDrag(slot, lx, gx, gy) {
            if (bar.availActive) return
            bar.lastMoveAt = Date.now()
            bar.dragActive = true
            bar.dragSlot = slot
            bar.grabX = lx
            bar.grabbedEntry = bar.disp[slot]
            bar.removeTarget = false
            bar.insertAt = slot
            bar.moveDrag(gx, gy)
        }

        function moveDrag(gx, gy) {
            bar.lastMoveAt = Date.now()
            var lp = content.mapFromGlobal(gx, gy)
            if (bar.dragActive) {
                bar.dragThumbX = lp.x - bar.grabX
                var cx = bar.dragThumbX + (bar.widths[bar.dragSlot] || 0) / 2
                bar.insertAt = bar.insertionIndex(cx)
                if (cx < -20 || cx > content.width + 20
                        || lp.y < -16 || lp.y > content.height + 16)
                    bar.insertAt = -1
                var ra = bar.removeArea
                bar.removeTarget = false
                if (ra !== null && ra !== undefined && ra.visible) {
                    var rm = ra.mapFromGlobal(gx, gy)
                    bar.removeTarget = rm.x >= 0 && rm.y >= 0
                            && rm.x <= ra.width && rm.y <= ra.height
                }
                if (bar.removeTarget) bar.insertAt = -1
            } else if (bar.availActive) {
                var over = lp.x >= -6 && lp.x <= content.width + 6
                        && lp.y >= -6 && lp.y <= content.height + 6
                bar.availOver = over
                if (over) {
                    bar.ghostX = Math.max(0, Math.min(content.width - 60, lp.x - bar.grabX))
                    bar.insertAt = bar.insertionIndex(bar.ghostX + availGhost.width / 2)
                } else {
                    bar.insertAt = -1
                }
            }
        }

        function endDrag() {
            if (!bar.dragActive) return
            var removing = bar.removeTarget
            var entry = bar.grabbedEntry
            var slot = bar.dragSlot
            var at = bar.insertAt
            bar.dragActive = false
            bar.dragSlot = -1
            bar.removeTarget = false
            bar.insertAt = -1
            bar.grabbedEntry = null
            if (entry === null || entry === undefined) return

            var a
            if (removing) {
                var gi = bar.disp.indexOf(entry)
                if (gi < 0) return
                a = bar.disp.slice()
                a.splice(gi, 1)
            } else {
                // `at < 0` means the pointer was outside the pill when the drag
                // ended. Return the row to its committed order instead of
                // bailing out, otherwise a lost pointer leaves the preview
                // showing a module that was never saved.
                if (at < 0) at = slot
                if (at > bar.disp.length) at = bar.disp.length
                a = bar.disp.slice()
                a.splice(slot, 1)
                if (at > slot) at -= 1
                a.splice(at, 0, entry)
            }

            bar.disp = a
            var changed = a.length !== bar.value.length
            if (!changed) {
                for (var i = 0; i < a.length; i++) {
                    if (a[i] !== bar.value[i]) { changed = true; break }
                }
            }
            if (changed) bar.edited(a)
        }

        function availBegin(name, lx, gx, gy) {
            bar.lastMoveAt = Date.now()
            bar.availActive = true
            bar.availName = name
            bar.grabX = lx
            var p = bar.thumbProps(name)
            availGhost.icon = p.icon
            availGhost.text = p.text
            availGhost.iconColor = p.color
            availGhost.segments = p.segments === true
            availGhost.segmentCount = p.segN
            availGhost.activeSegment = p.activeSeg !== undefined ? p.activeSeg : -1
            availGhost.flag = p.flag === true
            availGhost.flagColor = p.flagColor
            availGhost.iconSize = p.iconSize || 10
            bar.ghostX = -999
            bar.availOver = false
            bar.moveDrag(gx, gy)
        }
        function availMove(gx, gy) { if (bar.availActive) bar.moveDrag(gx, gy) }
        function availEnd() {
            if (!bar.availActive) return
            var ok = bar.availOver && bar.insertAt >= 0
            var at = bar.insertAt
            var name = bar.availName
            bar.availActive = false
            bar.availOver = false
            bar.insertAt = -1
            bar.ghostX = -999
            if (ok) {
                var a = bar.disp.slice()
                a.splice(Math.min(at, a.length), 0, name)
                bar.edited(a)
            }
        }
    }

    // Form for a custom pill module; keys match the README's "Custom pill
    // modules" section; only the filled-in keys are written.
    component CustomModuleForm: ColumnLayout {
        id: cf
        property var entry: null      // null = creating a new module
        // fully keyed so the bindings below never see undefined
        property var draft: ({ run: "", format: "", icon: "", tooltip: "", every: "", stream: false, click: "" })
        property bool missingRun: false
        signal accepted(var entry)
        signal rejected()

        readonly property bool editing: cf.entry !== null
        Layout.fillWidth: true

        function open() {
            var e = cf.entry || {}
            cf.missingRun = false
            cf.draft = {
                run: e.run || "",
                format: e.format || "",
                icon: e.icon || "",
                tooltip: e.tooltip || "",
                every: e.every ? String(e.every) : "",
                stream: e.stream === true,
                click: e.click || ""
            }
        }
        function field(k, v) {
            var d = Object.assign({}, cf.draft)
            d[k] = v
            cf.draft = d
        }
        function build() {
            var d = cf.draft
            var e = { run: String(d.run || "").trim() }
            var every = parseInt(d.every, 10) || 0
            if (String(d.format || "").trim() !== "") e.format = String(d.format).trim()
            if (String(d.icon || "").trim() !== "") e.icon = String(d.icon).trim()
            if (String(d.tooltip || "").trim() !== "") e.tooltip = String(d.tooltip).trim()
            if (String(d.click || "").trim() !== "") e.click = String(d.click).trim()
            if (d.stream === true) e.stream = true
            else if (every > 0) e.every = every
            return e
        }
        function save() {
            // commit focused fields — a click on Save can beat onEditingFinished
            if (runRow.input.activeFocus)    cf.field("run", runRow.input.text)
            if (formatRow.input.activeFocus) cf.field("format", formatRow.input.text)
            if (iconRow.input.activeFocus)   cf.field("icon", iconRow.input.text)
            if (tooltipRow.input.activeFocus) cf.field("tooltip", tooltipRow.input.text)
            if (everyRow.input.activeFocus)  cf.field("every", everyRow.input.text)
            if (clickRow.input.activeFocus)  cf.field("click", clickRow.input.text)

            if (String(cf.draft.run || "").trim() === "") {
                cf.missingRun = true
                return
            }
            cf.missingRun = false
            cf.accepted(cf.build())
        }

        Rectangle {
            Layout.fillWidth: true
            // mirror the inner column's implicit height (+ margins); anchoring
            // to fill would collapse the panel to zero height
            implicitHeight: cfInner.implicitHeight + 24
            color: th.bg1
            radius: 10
            border.color: th.borderBg3
            ColumnLayout {
                id: cfInner
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 12
                spacing: 0

                Row {
                    Layout.fillWidth: true
                    spacing: 10
                    Text {
                        text: cf.editing ? "EDIT CUSTOM MODULE" : "NEW CUSTOM MODULE"
                        color: th.fg4
                        font.family: th.fontFamily
                        font.pixelSize: 10
                        font.bold: true
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: cf.editing
                        text: cf.draft.run
                        color: th.fg6
                        font.family: th.fontFamily
                        font.pixelSize: 10
                        elide: Text.ElideMiddle
                    }
                }

                TextRow {
                    id: runRow
                    label: "Run"
                    hint: "Just the file name if the script is in ~/.config/chillpill-shell/modules, else ~ or an absolute path"
                    fieldWidth: 360
                    placeholder: "cpu-temp.sh"
                    value: cf.draft.run
                    onEdited: (v) => cf.field("run", v)
                }
                TextRow {
                    id: formatRow
                    label: "Format"
                    hint: "Bar text — placeholders: {text} {tooltip} {icon}"
                    fieldWidth: 240
                    placeholder: "{icon} {text}"
                    value: cf.draft.format
                    onEdited: (v) => cf.field("format", v)
                }
                TextRow {
                    id: iconRow
                    label: "Icon"
                    hint: "Nerd font glyph, used by the {icon} placeholder"
                    fieldWidth: 200
                    value: cf.draft.icon
                    onEdited: (v) => cf.field("icon", v)
                }
                TextRow {
                    id: tooltipRow
                    label: "Tooltip"
                    hint: "Hover text — placeholders: {text} {tooltip} {icon}"
                    fieldWidth: 240
                    value: cf.draft.tooltip
                    onEdited: (v) => cf.field("tooltip", v)
                }
                NumRow {
                    id: everyRow
                    label: "Refresh every"
                    hint: cf.draft.stream
                        ? "off while streaming"
                        : "Seconds between runs; 0 (or empty) runs once at startup"
                    from: 0; to: 86400; step: 1; suffix: "s"
                    value: Number(cf.draft.every) || 0
                    onEdited: (v) => cf.field("every", String(Math.round(v)))
                }
                ToggleRow {
                    label: "Streaming"
                    hint: "Keep the process running and update on every stdout line"
                    value: cf.draft.stream === true
                    onEdited: (v) => cf.field("stream", v)
                }
                TextRow {
                    id: clickRow
                    label: "Click"
                    hint: "Shell command run on left click"
                    fieldWidth: 240
                    value: cf.draft.click
                    onEdited: (v) => cf.field("click", v)
                }

                Text {
                    Layout.topMargin: 8
                    visible: cf.missingRun
                    text: "run is required — the command to execute"
                    color: th.deleting
                    font.family: th.fontFamily
                    font.pixelSize: 10
                }

                Row {
                    Layout.topMargin: 12
                    Layout.alignment: Qt.AlignRight
                    spacing: 8
                    FormBtn { label: "Cancel"; onClicked: cf.rejected() }
                    FormBtn { label: cf.editing ? "Save changes" : "Add module"; primary: true; onClicked: cf.save() }
                }
            }
        }
    }

    // Pill bar modules, previewed as thumbnails in bar order
    component ModulesEditor: ColumnLayout {
        id: m
        property var value: []
        property var known: []
        signal edited(var v)
        Layout.fillWidth: true
        spacing: 8

        // custom module form state
        property bool editingModule: false
        property int customIndex: -1

        readonly property var available: known.filter(k => value.indexOf(k) < 0)

        function openNewCustom() {
            m.customIndex = -1
            customForm.entry = null
            customForm.open()
            m.editingModule = true
        }
        function openEditCustom(i) {
            m.customIndex = i
            customForm.entry = m.value[i]
            customForm.open()
            m.editingModule = true
        }
        function saveCustom(entry) {
            var a = m.value.slice()
            if (m.customIndex >= 0) a[m.customIndex] = entry
            else a.push(entry)
            m.editingModule = false
            m.edited(a)
        }

        Text {
            visible: m.value.length > 0
            text: "Drag to Reorder \u00b7 Drag a module onto the list below to remove"
            color: th.fg4
            font.family: th.fontFamily
            font.pixelSize: 11
        }
        PillBarPreview {
            id: bar
            known: m.known
            value: m.value
            removeArea: leftoverArea
            onEdited: (v) => m.edited(v)
            onEditRequested: (slot) => m.openEditCustom(slot)
        }

        Text {
            Layout.fillWidth: true
            visible: m.value.length === 0
            text: "The pill bar is empty, drag a module below onto it"
            color: th.fg6
            font.family: th.fontFamily
        }

        // modules not in the bar yet + custom module action
        Text {
            text: "ADD MODULES"
            color: th.fg4
            font.family: th.fontFamily
            font.pixelSize: 10
        }
        Item {
            id: leftoverArea
            Layout.fillWidth: true
            implicitHeight: leftoverFlow.implicitHeight

            Rectangle {
                id: dropZone
                anchors.fill: parent
                radius: 12
                z: 2
                visible: opacity > 0.01
                opacity: bar.dragActive ? 1 : 0
                color: bar.removeTarget ? "#1ce32626" : "#0a9e9e9e"
                border.color: bar.removeTarget ? "#4de32626" : "#1c9e9e9e"
                border.width: 1
                Behavior on opacity { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 130 } }
                Behavior on border.color { ColorAnimation { duration: 130 } }

                Rectangle {
                    id: dropBadge
                    anchors.centerIn: parent
                    width: dropRow.implicitWidth + 26
                    height: 28
                    radius: 14
                    color: bar.removeTarget ? "#2be32626" : "#1a9e9e9e"
                    border.color: bar.removeTarget ? "#7ae32626" : "#2e9e9e9e"
                    border.width: 1
                    scale: bar.removeTarget ? 1 : 0.92
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                    Behavior on color { ColorAnimation { duration: 130 } }
                    Behavior on border.color { ColorAnimation { duration: 130 } }

                    Row {
                        id: dropRow
                        anchors.centerIn: parent
                        spacing: 7
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: String.fromCodePoint(0xef90)
                            color: bar.removeTarget ? th.deleting : th.fg4
                            font.family: th.nerdFontFamily
                            font.pixelSize: 11
                            Behavior on color { ColorAnimation { duration: 130 } }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "release to remove"
                            color: bar.removeTarget ? th.deleting : th.fg4
                            font.family: th.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 0.3
                            Behavior on color { ColorAnimation { duration: 130 } }
                        }
                    }
                }
            }

            Flow {
                id: leftoverFlow
                width: parent.width
                spacing: 12
                Repeater {
                    model: m.available
                    ModuleThumb {
                        id: addThumb
                        required property string modelData
                        height: 30
                        readonly property var props: bar.thumbProps(modelData)
                        icon: props.icon
                        text: props.text
                        iconColor: props.color
                        segments: props.segments === true
                        segmentCount: props.segN || 0
                        activeSegment: props.activeSeg !== undefined ? props.activeSeg : -1
                        flag: props.flag === true
                        flagColor: props.flagColor
                        iconSize: props.iconSize || 10
                        removable: false
                        onDragBegin: (lx, gx, gy) => bar.availBegin(modelData, lx, gx, gy)
                        onDragMove: (gx, gy) => bar.availMove(gx, gy)
                        onDragEnd: bar.availEnd
                    }
                }
            }
        }

        Rectangle {
            id: customAdd
            Layout.alignment: Qt.AlignLeft
            implicitWidth: customAddLbl.implicitWidth + 26
            height: 30; radius: 15
            color: customAddMa.containsMouse ? th.accent : "transparent"
            border.color: th.accent
            Text {
                id: customAddLbl
                anchors.centerIn: parent
                text: "+ Custom module"
                color: customAddMa.containsMouse ? th.bgD : th.accent
                font.family: th.fontFamily
            }
            MouseArea {
                id: customAddMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: m.openNewCustom()
            }
        }

        Text {
            Layout.fillWidth: true
            visible: m.value.length > 0 && m.available.length === 0
            text: "Every built-in module is in the bar"
            color: th.fg6
            font.family: th.fontFamily
        }

        CustomModuleForm {
            id: customForm
            Layout.fillWidth: true
            Layout.topMargin: 4
            visible: m.editingModule
            onAccepted: (entry) => m.saveCustom(entry)
            onRejected: m.editingModule = false
        }
    }

    // Number chips (timer presets)
    component NumChips: ColumnLayout {
        id: nc
        property var value: []
        property string suffix: ""
        signal edited(var v)
        Layout.fillWidth: true

        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: nc.value
                Rectangle {
                    id: nchip
                    required property int index
                    required property var modelData
                    width: nl.implicitWidth + 40; height: 30; radius: 15
                    color: th.bg2
                    Text { id: nl; x: 12; anchors.verticalCenter: parent.verticalCenter; text: nchip.modelData + nc.suffix; color: th.fg; font.family: th.fontFamily }
                    Text {
                        anchors.right: parent.right; anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: "✕"; color: th.fg5
                        font.family: th.fontFamily
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { var a = nc.value.slice(); a.splice(nchip.index, 1); nc.edited(a) }
                        }
                    }
                }
            }
            Rectangle {
                // sized from the placeholder so the hint always sits inside the pill;
                // the 16px margins match, so typed digits line up with the hint text
                width: addHint.implicitWidth + 32; height: 30; radius: 15; color: th.bg1
                border.color: ni.activeFocus ? th.borderBgFocus : th.borderBg2
                TextInput {
                    id: ni
                    anchors.fill: parent
                    anchors.leftMargin: 16; anchors.rightMargin: 16
                    verticalAlignment: TextInput.AlignVCenter
                    color: th.fg
                    font.family: th.fontFamily
                    inputMethodHints: Qt.ImhDigitsOnly
                    onAccepted: {
                        var v = Number(text)
                        if (!isNaN(v) && v > 0 && nc.value.indexOf(v) < 0)
                            nc.edited(nc.value.concat([v]).sort((a, b) => a - b))
                        text = ""
                    }
                }
                Text {
                    id: addHint
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    verticalAlignment: Text.AlignVCenter
                    visible: ni.text === "" && !ni.activeFocus
                    text: "add + Enter"
                    color: th.fg6
                    font.family: th.fontFamily
                }
            }
        }
        Text {
            Layout.fillWidth: true
            visible: nc.value.length === 0
            text: "No presets — type a number and press Enter"
            color: th.fg6
            font.family: th.fontFamily
        }
    }

    component Page: Item {
        id: pg
        default property alias items: col.data
        property string title: ""
        readonly property alias flickable: flick
        readonly property alias scrollbar: vbar
        Flickable {
            id: flick
            anchors.fill: parent
            contentHeight: col.implicitHeight + 60
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ColumnLayout {
                id: col
                x: 28; y: 24
                width: Math.min(flick.width - 56, 760)
                spacing: 0
            }
        }
        // vertical scrollbar: visible only while a page is taller than the
        // window; drag the handle to scroll, click the track to jump there
        Item {
            id: vbar
            visible: flick.visibleArea.heightRatio < 1.0
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 6
            width: 8
            opacity: vbarHover.hovered || thumbMa.dragging ? 1 : 0.7
            Behavior on opacity { NumberAnimation { duration: 120 } }

            // track
            Rectangle {
                anchors.fill: parent
                radius: 4
                color: th.bg3
            }
            // track click: jump so the thumb centres under the cursor
            MouseArea {
                id: trackMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: (mouse) => {
                    if (mouse.y >= thumb.y && mouse.y <= thumb.y + thumb.height) return
                    thumb.jumpTo(mouse.y)
                }
            }
            // thumb / handle
            Rectangle {
                id: thumb
                x: 1
                width: parent.width - 2
                radius: 3
                color: th.bg8
                readonly property real maxY: Math.max(0, vbar.height - thumb.height)
                readonly property real trackY: flick.visibleArea.heightRatio < 1
                    ? flick.visibleArea.yPosition * maxY : 0
                height: Math.max(28, flick.visibleArea.heightRatio * vbar.height)
                y: thumbMa.dragging ? thumbMa.dragY : trackY
                function jumpTo(my) {
                    var ny = Math.max(0, Math.min(my - thumb.height / 2, thumb.maxY))
                    var f = ny / Math.max(1, thumb.maxY)
                    flick.contentY = f * (flick.contentHeight - flick.height)
                }
                MouseArea {
                    id: thumbMa
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    property real dragY: 0
                    property real grabOffset: 0
                    property bool dragging: false
                    onPressed: (mouse) => {
                        thumbMa.grabOffset = mouse.y
                        thumbMa.dragY = thumb.y
                        thumbMa.dragging = true
                    }
                    onReleased: thumbMa.dragging = false
                    onPositionChanged: (mouse) => {
                        if (!pressed) return
                        var ny = Math.max(0, Math.min(thumb.maxY,
                            thumbMa.dragY + (mouse.y - thumbMa.grabOffset)))
                        thumbMa.dragY = ny
                        var f = ny / Math.max(1, thumb.maxY)
                        flick.contentY = f * (flick.contentHeight - flick.height)
                    }
                }
            }
            HoverHandler { id: vbarHover }
        }
    }

    component Heading: Text {
        Layout.topMargin: 14
        Layout.bottomMargin: 6
        color: th.fg4
        font.family: th.fontFamily
        font.pixelSize: 10
        font.bold: true
    }

    // ───────────────────────────── window ─────────────────────────────

    FloatingWindow {
        id: win
        title: "ChillPill Settings"
        color: th.bgD
        implicitWidth: 940
        implicitHeight: 660
        minimumSize: Qt.size(720, 480)
        visible: true

        property int current: 0
        // fade the content in when switching sections; the sidebar highlight
        // already eases via its own color animation
        onCurrentChanged: pageFade.restart()
        NumberAnimation {
            id: pageFade
            target: stack
            property: "opacity"
            from: 0
            to: 1
            duration: 170
            easing.type: Easing.OutCubic
        }
        // icon codepoints verified present in the configured nerd font
        readonly property var pages: [
            { name: "Appearance",     icon: String.fromCodePoint(0xf03d8) }, // md-palette
            { name: "Pill",           icon: String.fromCodePoint(0xf0402) }, // md-pill
            { name: "Notifications",  icon: String.fromCodePoint(0xf0f3)  }, // fa-bell
            { name: "Media & OSD",    icon: String.fromCodePoint(0xf0387) }, // md-music_note
            { name: "Weather & Data", icon: String.fromCodePoint(0xf015f) }, // md-cloud
            { name: "System",         icon: String.fromCodePoint(0xf0493) }, // md-cog
            { name: "Wallpaper",      icon: String.fromCodePoint(0xf0e09) }  // md-wallpaper
        ]

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // sidebar
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 200
                color: th.bgD1
                ColumnLayout {
                    anchors.fill: parent
                    anchors.topMargin: 20
                    anchors.margins: 12
                    spacing: 4
                    // wordmark, aligned with the nav rows below
                    ColumnLayout {
                        Layout.leftMargin: 12
                        Layout.bottomMargin: 10
                        spacing: 1
                        Text {
                            text: "ChillPill"
                            color: th.fgL
                            font.family: th.fontFamily
                            font.pixelSize: 19
                            font.bold: true
                        }
                        Text {
                            text: "SETTINGS"
                            color: th.accent
                            font.family: th.fontFamily
                            font.pixelSize: 10
                            font.letterSpacing: 3
                        }
                    }
                    Repeater {
                        model: win.pages
                        Rectangle {
                            id: nav
                            required property int index
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 38; radius: 8
                            color: win.current === nav.index ? th.bg6 : (nma.containsMouse ? th.bg3 : "transparent")
                            Behavior on color { ColorAnimation { duration: 90 } }
                            Rectangle {
                                // active-page indicator
                                x: 2
                                width: 3; height: 20; radius: 1.5
                                anchors.verticalCenter: parent.verticalCenter
                                visible: win.current === nav.index
                                color: th.accent
                            }
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                x: 12
                                spacing: 10
                                Text {
                                    text: nav.modelData.icon
                                    color: win.current === nav.index ? th.fg : th.fg3
                                    font.family: th.nerdFontFamily
                                    font.pixelSize: 14
                                }
                                Text {
                                    text: nav.modelData.name
                                    color: win.current === nav.index ? th.fg : th.fg3
                                    font.family: th.fontFamily
                                }
                            }
                            MouseArea {
                                id: nma
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.current = nav.index
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: th.bg3
                        Layout.topMargin: 8
                        Layout.bottomMargin: 8
                    }
                    Text {
                        text: root.configPath
                        color: th.fg6
                        font.family: th.fontFamily
                        font.pixelSize: 10
                        wrapMode: Text.WrapAnywhere
                        Layout.fillWidth: true
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 6
                        Text { text: root.status; color: root.statusError ? th.deleting : th.fg4; font.family: th.fontFamily; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight }
                        MiniBtn { label: "⟳"; onClicked: file.reload() }
                    }
                }
            }

            // content
            StackLayout {
                id: stack
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: win.current
                enabled: root.loaded

                // 0 — Appearance
                Page {
                    Heading { text: "IDENTITY" }
                    TextRow { label: "Display picture"; hint: "Shown in the Mini Dashboard"; value: root.get("displayPicture", ""); onEdited: (v) => root.set("displayPicture", v) }
                    Heading { text: "FONTS" }
                    TextRow { label: "Text font"; value: root.get("textFontFamily", ""); onEdited: (v) => root.set("textFontFamily", v) }
                    TextRow { label: "Nerd font"; hint: "Used for icons"; value: root.get("nerdFontFamily", ""); onEdited: (v) => root.set("nerdFontFamily", v) }
                    Heading { text: "SCALE & POSITION" }
                    SliderRow { label: "Pill scale"; from: 0.5; to: 2; step: 0.05; value: root.get("pillScale", 1); onEdited: (v) => root.set("pillScale", v) }
                    SliderRow { label: "DPI scale"; from: 0.5; to: 3; step: 0.05; value: root.get("dpiScale", 1); onEdited: (v) => root.set("dpiScale", v) }
                    NumRow { label: "Pill top margin"; to: 200; suffix: "px"; value: root.get("pillTopMargin", 9); onEdited: (v) => root.set("pillTopMargin", v) }
                    NumRow { label: "Pill bottom margin"; to: 200; suffix: "px"; value: root.get("pillBottomMargin", 26); onEdited: (v) => root.set("pillBottomMargin", v) }
                    ToggleRow { label: "Audio visualizer"; hint: "Shown in the Control Center's Media Player";  value: root.get("showAudioVisuals", true); onEdited: (v) => root.set("showAudioVisuals", v) }
                }

                // 1 — Pill
                Page {
                    Heading { text: "MODULES (LEFT → RIGHT)" }
                    ModulesEditor {
                        known: ["battery", "volume", "workspaces", "network", "clock", "brightness", "vpn", "notifications", "bluetooth", "weather"]
                        value: root.cfg.pillModules === undefined ? [] : root.cfg.pillModules
                        onEdited: (v) => root.set("pillModules", v)
                    }
                    Heading { text: "BEHAVIOUR" }
                    ToggleRow { label: "Show pill on hover"; hint: "Auto hide the Pill Bar"; value: root.get("pillOnHover", false); onEdited: (v) => root.set("pillOnHover", v) }
                    TextRow { label: "Clock format"; hint: "Qt format string, e.g. hh:mm or h:mm AP"; fieldWidth: 160; value: root.get("clockFormat", "hh:mm"); onEdited: (v) => root.set("clockFormat", v) }
                    NumRow { label: "Max workspaces"; from: 1; to: 20; value: root.get("maxWorkspaces", 5); onEdited: (v) => root.set("maxWorkspaces", v) }
                }

                // 2 — Notifications
                Page {
                    Heading { text: "NOTIFICATIONS" }
                    NumRow { label: "Display time"; from: 500; to: 60000; step: 500; suffix: "ms"; value: root.get("notificationDisplayTime", 3000); onEdited: (v) => root.set("notificationDisplayTime", v) }
                    NumRow { label: "Max notifications in stack"; from: 1; to: 200; value: root.get("maxNotificationsInStack", 20); onEdited: (v) => root.set("maxNotificationsInStack", v) }
                    ToggleRow { label: "Avoid duplicate notifications"; hint: "Collapse repeats into a counter"; value: root.get("avoidDuplicateNotifications", true); onEdited: (v) => root.set("avoidDuplicateNotifications", v) }
                    Heading { text: "PRIVACY" }
                    ToggleRow { label: "Show sensitive info"; hint: "VPN module's information (City, IP Address etc.)"; value: root.get("showSensitiveInfo", true); onEdited: (v) => root.set("showSensitiveInfo", v) }
                }

                // 3 — Media & OSD
                Page {
                    NumRow { label: "Media popup duration"; from: 200; to: 30000; step: 100; suffix: "ms"; value: root.get("mediaPopupDuration", 2000); onEdited: (v) => root.set("mediaPopupDuration", v) }
                    NumRow { label: "OSD duration"; hint: "On Screen Display"; from: 100; to: 10000; step: 100; suffix: "ms"; value: root.get("osdDuration", 800); onEdited: (v) => root.set("osdDuration", v) }
                    NumRow { label: "Max volume"; hint: "Above 100 enables software boost"; from: 50; to: 200; step: 5; suffix: "%"; value: root.get("maxVolume", 100); onEdited: (v) => root.set("maxVolume", v) }
                    Heading { text: "TIMER PRESETS (MINUTES)" }
                    NumChips { suffix: "m"; value: root.get("timerPresets", []); onEdited: (v) => root.set("timerPresets", v) }
                }

                // 4 — Weather & Data
                Page {
                    Heading { text: "WEATHER" }
                    TextRow { label: "Location"; hint: "City name for weather"; fieldWidth: 200; value: root.get("weatherLocation", ""); onEdited: (v) => root.set("weatherLocation", v) }
                    ChoiceRow { label: "Units"; options: ["metric", "imperial"]; value: root.get("weatherUnits", "metric"); onEdited: (v) => root.set("weatherUnits", v) }
                    NumRow { label: "Refresh interval"; from: 60000; to: 86400000; step: 60000; divisor: 60000; suffix: "min"; value: root.get("weatherRefreshInterval", 3600000); onEdited: (v) => root.set("weatherRefreshInterval", v) }
                    TextRow { label: "Country"; hint: "ISO 3166-1 alpha-2 (IN) or Country Name (India)"; fieldWidth: 80; value: root.get("country", ""); onEdited: (v) => root.set("country", v.toUpperCase()) }
                    Heading { text: "NETWORK USAGE" }
                    NumRow { label: "Data usage refresh"; hint: "Only refreshes while the Mini Dashboard is open"; from: 60000; to: 86400000; step: 60000; divisor: 60000; suffix: "min"; value: root.get("dataUsageRefreshInterval", 300000); onEdited: (v) => root.set("dataUsageRefreshInterval", v) }
                }

                // 5 — System
                Page {
                    Heading { text: "APPLICATIONS" }
                    TextRow { label: "Default terminal"; hint: "To open Console-Only apps in the Terminal"; fieldWidth: 200; value: root.get("defaultTerminal", ""); onEdited: (v) => root.set("defaultTerminal", v) }
                    TextRow { label: "Screen lock command"; fieldWidth: 200; value: root.get("screenLockAppCommand", ""); onEdited: (v) => root.set("screenLockAppCommand", v) }
                    ToggleRow { label: "Confirm power actions"; hint: "Confirm the power action prompt (Shutdown, Restart, Logout)"; value: root.get("confirmPowerActions", true); onEdited: (v) => root.set("confirmPowerActions", v) }
                    Heading { text: "CLIPBOARD" }
                    ToggleRow { label: "Auto delete cliphist image cache"; hint: "Delete the cache image also as you delete the clipboard image"; value: root.get("deleteCliphistImgCache", true); onEdited: (v) => root.set("deleteCliphistImgCache", v) }
                    ToggleRow { label: "Separate preview tab types"; hint: "Skip the previous/next clipboard item if it doesn't match with the current selected item"; value: root.get("separatePreviewTabTypes", true); onEdited: (v) => root.set("separatePreviewTabTypes", v) }
                }

                // 6 — Wallpaper
                Page {
                    Heading { text: "WALLPAPER" }
                    TextRow { label: "Wallpapers directory"; fieldWidth: 320; value: root.get("wallpapersDir", ""); onEdited: (v) => root.set("wallpapersDir", v) }
                    TextRow { label: "Custom wallpaper script"; hint: "Empty = awww (wallpaper switcher tool)"; fieldWidth: 320; placeholder: "/path/to/script.sh"; value: root.get("customWallpaperScript", ""); onEdited: (v) => root.set("customWallpaperScript", v) }
                    Heading { text: "SWITCHER" }
                    ToggleRow { label: "Close switcher after setting"; value: root.get("wsCloseOnWallpaperSet", true); onEdited: (v) => root.set("wsCloseOnWallpaperSet", v) }
                    ToggleRow { label: "Wallpaper switcher animation"; value: root.get("wsAnimation", true); onEdited: (v) => root.set("wsAnimation", v) }
                }
            }
        }
    }
}
