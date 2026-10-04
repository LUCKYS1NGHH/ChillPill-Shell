import QtQuick
import QtQuick.Layouts
import "components"
import "."

Item {
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

    readonly property real ps: Math.max(0.5, ConfigStore.get("pillScale", 1))
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
        case "volume":        return { icon: String.fromCodePoint(0xf057e), color: Theme.fg,     text: "64%" }
        case "workspaces":    return { icon: "",       color: Theme.fg,     text: "", segments: true, n: Math.min(Math.max(ConfigStore.get("maxWorkspaces", 5), 1), 6) }
        case "network":       return { icon: String.fromCodePoint(0xf0928), color: "#6791dc", text: "Home" }
        case "clock":         return { icon: "",       color: Theme.fg,     text: Qt.formatTime(new Date(), ConfigStore.get("clockFormat", "hh:mm")) }
        case "brightness":    return { icon: String.fromCodePoint(0xf00e0), color: Theme.fg,     text: "84%" }
        case "vpn":           return { icon: String.fromCodePoint(0xf099d), color: "#48cc47", text: "on" }
        case "notifications": return { icon: String.fromCodePoint(0xf0f3),  color: "#e2b052", text: "7" }
        case "bluetooth":     return { icon: String.fromCodePoint(0xf00af), color: "#6591e0", text: "on", iconSize: 13 }
        case "weather":       return { icon: String.fromCodePoint(0xe312),  color: "#d8ad5c", text: "24°C", iconSize: 11 }
        case "audioVisualizer": return { icon: "",       spectrum: true, color: Theme.fg,     text: "" }
        default:              return { icon: String.fromCodePoint(0xf016),  color: Theme.fg4,    text: name }
        }
    }

    function thumbProps(entry) {
        if (typeof entry === "object" && entry !== null) {
            var base = entry.run ? String(entry.run).split("/").pop() : "custom"
            return {
                icon: entry.icon || "",
                color: Theme.fg,
                text: base,
                segments: false, segN: 0, activeSeg: -1,
                spectrum: false,
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
            spectrum: s.spectrum === true,
            flag: unk, flagColor: Theme.warning,
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
                    spectrum: props.spectrum === true
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
                color: Theme.fgL
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
                color: Theme.fg6
                font.family: Theme.fontFamily
            }

            Text {
                anchors.centerIn: parent
                visible: bar.disp.length > bar.poolSize
                text: "only the first " + bar.poolSize + " modules are shown here"
                color: Theme.warning
                font.family: Theme.fontFamily
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