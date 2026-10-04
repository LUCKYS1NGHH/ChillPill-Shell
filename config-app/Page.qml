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
