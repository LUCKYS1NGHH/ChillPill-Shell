import QtQuick
import QtQuick.Layouts
import "components"
import "."

Item {
    id: pg
    default property alias items: col.data
    property string title: ""
    readonly property alias flickable: flick
    readonly property alias scrollbar: vbar

    // ── search ──
    // Query from the sidebar. Rows match on label + hint; a matching Heading
    // reveals its whole section, a matching row only itself. Label-less
    // controls (ModulesEditor, NumChips) follow their section.
    property string filter: ""
    property int matchCount: 0

    onFilterChanged: applyFilter()
    Component.onCompleted: applyFilter()
    // a hidden page can't read back its rows' visible, so re-apply on show
    onVisibleChanged: if (visible) applyFilter()

    function applyFilter() {
        if (!col) return // ids resolve after creation
        var q = filter.trim().toLowerCase()
        var list = col.data
        var i, it
        if (q === "") {
            for (i = 0; i < list.length; i++) list[i].visible = true
            matchCount = 0
            return
        }

        // 2 = heading, 1 = labelled row, 0 = section control
        var kind = [], hay = []
        for (i = 0; i < list.length; i++) {
            it = list[i]
            if (it.label !== undefined) {
                kind.push(1)
                hay.push((it.label + " " + (it.hint || "")).toLowerCase())
            } else if (it.text !== undefined) {
                kind.push(2)
                hay.push(it.text.toLowerCase())
            } else {
                kind.push(0)
                hay.push("")
            }
        }

        // per heading: own text hit? section hit?
        var headText = [], headHit = []
        var cur = -1
        for (i = 0; i < list.length; i++) {
            if (kind[i] === 2) {
                cur = i
                headText[i] = hay[i].indexOf(q) >= 0
                headHit[i] = headText[i]
            } else if (cur >= 0 && kind[i] === 1 && hay[i].indexOf(q) >= 0) {
                headHit[cur] = true
            }
        }

        // decide then write; reading visible back gives false on hidden pages
        var show = [], n = 0
        cur = -1
        for (i = 0; i < list.length; i++) {
            var s
            if (kind[i] === 2) {
                cur = i
                s = headHit[i]
            } else if (cur < 0) {
                // rows above the first heading stand alone
                s = kind[i] === 1 && hay[i].indexOf(q) >= 0
            } else if (kind[i] === 1) {
                s = headText[cur] || hay[i].indexOf(q) >= 0
            } else {
                // no label of its own, follow the section
                s = headHit[cur]
            }
            show[i] = s
            if (s && kind[i] !== 2) n++
        }
        for (i = 0; i < list.length; i++) list[i].visible = show[i]
        matchCount = n
    }

    readonly property bool empty: filter !== "" && matchCount === 0

    Flickable {
        id: flick
        anchors.fill: parent
        visible: !pg.empty
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
    // empty state
    Text {
        anchors.centerIn: parent
        visible: pg.empty
        text: "No settings match \u201C" + pg.filter + "\u201D"
        color: Theme.fg5
        font.family: Theme.fontFamily
        font.pixelSize: 13
    }
    Item {
        id: vbar
        visible: flick.visibleArea.heightRatio < 1.0 && !pg.empty
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 6
        width: 8
        opacity: vbarHover.hovered || thumbMa.dragging ? 1 : 0.7
        Behavior on opacity { NumberAnimation { duration: 120 } }

        Rectangle {
            anchors.fill: parent
            radius: 4
            color: Theme.bg3
        }
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
        Rectangle {
            id: thumb
            x: 1
            width: parent.width - 2
            radius: 3
            color: Theme.bg8
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
