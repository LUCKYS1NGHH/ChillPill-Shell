import QtQuick
import QtQuick.Layouts
import "../"

RowLayout {
    id: row
    property string label: ""
    property string hint: ""
    property string archPkg: ""
    property string copyCmd: ""
    property bool found: false
    property string cat: "required"
    signal copyRequested(string text)

    Layout.fillWidth: true
    spacing: 10

    Text {
        text: row.found ? "\u2713" : "\u2715"
        color: row.found ? Theme.ok : (row.cat === "runtime" ? Theme.warning : Theme.deleting)
        font.family: Theme.fontFamily
        font.pixelSize: 13
        font.bold: true
    }
    Column {
        Layout.fillWidth: true
        spacing: 1
        Text {
            text: row.label
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }
        Text {
            text: row.hint
            color: Theme.fg5
            font.family: Theme.fontFamily
            font.pixelSize: 10
            visible: row.hint !== ""
        }
    }
    Text {
        visible: row.archPkg !== ""
        text: row.archPkg
        color: row.found ? Theme.fg5 : Theme.fg3
        font.family: Theme.nerdFontFamily
        font.pixelSize: 10
        Layout.maximumWidth: 190
        elide: Text.ElideRight
    }
    Rectangle {
        visible: row.archPkg !== ""
        width: 20; height: 22; radius: 5
        color: cma.containsMouse ? Theme.bg6 : "transparent"
        Text {
            anchors.centerIn: parent
            text: "\uf0c5" // fa-copy
            color: cma.containsMouse ? Theme.fg : Theme.fg4
            font.family: Theme.nerdFontFamily
            font.pixelSize: 11
        }
        MouseArea {
            id: cma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.copyRequested(row.copyCmd !== "" ? row.copyCmd : row.archPkg)
        }
    }
}