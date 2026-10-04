import QtQuick
import QtQuick.Layouts
import "components"
import "."

Rectangle {
    id: mt

    property string icon: ""
    property string text: ""
    property color iconColor: Theme.fg
    property bool segments: false
    property bool spectrum: false
    property int segmentCount: 5
    property int activeSegment: -1
    property bool flag: false
    property color flagColor: Theme.accent
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

    readonly property real ps: Math.max(0.5, ConfigStore.get("pillScale", 1))
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
                        font.family: Theme.fontFamily
                        font.pixelSize: 9 * mt.ps
                    }
                }
            }
        }
        AudioVisualPreview {
            visible: mt.spectrum
            Layout.fillWidth: false
            ps: mt.ps
        }
        Text {
            visible: !mt.segments && !mt.spectrum && mt.icon !== ""
            text: mt.icon
            color: mt.iconColor
            font.family: Theme.nerdFontFamily
            font.pixelSize: mt.iconSize * mt.ps
        }
        Text {
            visible: !mt.segments && mt.text !== ""
            text: mt.text
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: 10 * mt.ps
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: ma.dragged ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        property point pressPt: Qt.point(0, 0)
        property bool dragged: false
        property real lastGX: 0
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
