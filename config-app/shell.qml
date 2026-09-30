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
        // so ModuleChip's hover state includes this control
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

    // one pill module; top row = left edge of the bar; contols quiet till hover
    component ModuleChip: Rectangle {
        id: mc
        required property int position
        required property var entry
        required property var known
        required property bool first
        required property bool last
        signal shifted(int delta)
        signal removed()
        signal editRequested()

        // string name, or a custom module obj
        readonly property bool isCustom: typeof entry === "object" && entry !== null
        readonly property string name: isCustom
            ? (entry.run ? String(entry.run).split("/").pop() : "custom")
            : String(entry)
        // unknown names dont render in the bar, flag them
        readonly property bool unknown: !mc.isCustom && mc.known.indexOf(mc.name) < 0
        // hovering the chip or any of its contols
        readonly property bool hot: hover.hovered || upBtn.hovered || downBtn.hovered
                                   || delBtn.hovered || editBtn.hovered

        Layout.fillWidth: true
        implicitHeight: 34
        radius: 8
        color: mc.hot ? th.bg4 : th.bg1
        border.color: mc.hot ? th.borderBg1 : th.borderBg3
        Behavior on color { ColorAnimation { duration: 100 } }
        Behavior on border.color { ColorAnimation { duration: 100 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 6
            spacing: 10

            Text {
                text: mc.position + 1
                color: th.fg5
                font.family: th.fontFamily
                font.pixelSize: 11
                Layout.preferredWidth: 16
                horizontalAlignment: Text.AlignRight
            }
            Text {
                text: mc.name
                color: th.fg
                font.family: th.fontFamily
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Rectangle {
                visible: mc.isCustom || mc.unknown
                implicitWidth: tagLbl.implicitWidth + 10
                implicitHeight: 16
                radius: 4
                color: "transparent"
                border.width: 1
                border.color: mc.unknown ? th.warning : th.borderBg1
                Text {
                    id: tagLbl
                    anchors.centerIn: parent
                    text: mc.isCustom ? "custom" : "unknown"
                    color: mc.unknown ? th.warning : th.fg5
                    font.family: th.fontFamily
                    font.pixelSize: 9
                }
            }
            Row {
                spacing: 2
                ChipBtn { id: editBtn; label: "✎"; visible: mc.isCustom; onClicked: mc.editRequested() }
                ChipBtn { id: upBtn; label: "↑"; dim: mc.first; onClicked: mc.shifted(-1) }
                ChipBtn { id: downBtn; label: "↓"; dim: mc.last; onClicked: mc.shifted(1) }
                ChipBtn { id: delBtn; label: "✕"; danger: true; onClicked: mc.removed() }
            }
        }

        HoverHandler { id: hover }
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

    // Pill bar modules as chips, in bar order
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

        function move(i, d) {
            var a = value.slice(), j = i + d
            if (j < 0 || j >= a.length) return
            var t = a[i]; a[i] = a[j]; a[j] = t
            edited(a)
        }
        function removeAt(i) { var a = value.slice(); a.splice(i, 1); edited(a) }
        function add(name) {
            name = name.trim()
            if (!name || value.indexOf(name) >= 0) return
            edited(value.concat([name]))
        }

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

        // modules in the bar; top = left edge
        Text {
            visible: m.value.length > 0
            text: "IN THE PILL BAR"
            color: th.fg4
            font.family: th.fontFamily
            font.pixelSize: 10
            font.bold: true
        }
        ColumnLayout {
            Layout.fillWidth: true
            visible: m.value.length > 0
            spacing: 4
            Repeater {
                model: m.value
                ModuleChip {
                    id: mod
                    required property int index
                    required property var modelData
                    position: mod.index
                    entry: mod.modelData
                    known: m.known
                    first: mod.index === 0
                    last: mod.index === m.value.length - 1
                    onShifted: (delta) => m.move(mod.index, delta)
                    onRemoved: m.removeAt(mod.index)
                    onEditRequested: m.openEditCustom(mod.index)
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: m.value.length === 0
            text: "The pill bar is empty — add a module below"
            color: th.fg6
            font.family: th.fontFamily
        }

        // modules not in the bar yet + custom module action
        Text {
            Layout.topMargin: 8
            text: "ADD MODULES"
            color: th.fg4
            font.family: th.fontFamily
            font.pixelSize: 10
            font.bold: true
        }
        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: m.available
                Rectangle {
                    id: addChip
                    required property string modelData
                    width: addLbl.implicitWidth + 26; height: 30; radius: 15
                    color: addMa.containsMouse ? th.accent : th.bg1
                    border.color: addMa.containsMouse ? th.accent : th.borderBg3
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text {
                        id: addLbl
                        anchors.centerIn: parent
                        text: "+ " + addChip.modelData
                        color: addMa.containsMouse ? th.bgD : th.fg4
                        font.family: th.fontFamily
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    MouseArea {
                        id: addMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: m.add(addChip.modelData)
                    }
                }
            }
            Rectangle {
                id: customAdd
                width: customAddLbl.implicitWidth + 26; height: 30; radius: 15
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
                        value: root.get("pillModules", [])
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
