import QtQuick
import QtQuick.Layouts
import "components"
import "."

ColumnLayout {
    id: cf
    property var entry: null
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
        implicitHeight: cfInner.implicitHeight + 24
        color: Theme.bg1
        radius: 10
        border.color: Theme.borderBg3
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
                    color: Theme.fg4
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.bold: true
                }
                Text {
                    Layout.fillWidth: true
                    visible: cf.editing
                    text: cf.draft.run
                    color: Theme.fg6
                    font.family: Theme.fontFamily
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
                color: Theme.deleting
                font.family: Theme.fontFamily
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
