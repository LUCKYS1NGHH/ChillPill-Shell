import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    clip: true

    property bool shown: false
    property int selectedIndex: 0
    property var entries: []   // list of { id, label }

    signal closeRequested()

    width: 320
    height: 180
    visible: shown
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 150 } }

    onShownChanged: {
        if (shown) {
            refresh()
            selectedIndex = 0
            forceActiveFocus()
        }
    }

    function refresh() {
        listProc.running = false
        listProc.running = true
    }

    function copySelected() {
        if (entries.length === 0) return
        let entry = entries[selectedIndex]
        copyProc.command = ["sh", "-c", "cliphist decode " + entry.id + " | wl-copy"]
        copyProc.running = false
        copyProc.running = true
        root.closeRequested()
    }

    Process {
        id: listProc
        command: ["cliphist", "list"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.split("\n").filter(l => l.length > 0)
                root.entries = lines.map(line => {
                    let tabIdx = line.indexOf("\t")
                    return {
                        id: line.substring(0, tabIdx),
                        label: line.substring(tabIdx + 1)
                    }
                })
            }
        }
    }

    Process {
        id: copyProc
        running: false
    }

    Rectangle {
        anchors.fill: parent
        radius: 15
        color: "#1a1a1a"
        border.color: "#333"
        border.width: 1
        clip: true
    }

    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8
        clip: true

        Text {
            text: "Clipboard History"
            color: Theme.fg
            font { family: Theme.fontFamily; pixelSize: 11; weight: 700 }
            anchors.left: parent.left
            anchors.leftMargin: 4
        }

        ListView {
            id: listView
            width: parent.width
            height: parent.height - 35
            clip: true
            model: root.entries
            currentIndex: root.selectedIndex
            highlightMoveDuration: 80

            delegate: Rectangle {
                width: listView.width
                height: 30
                radius: 6
                color: index === root.selectedIndex ? "#353535" : "transparent"

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    text: modelData.label
                    color: Theme.fg
                    font { family: Theme.fontFamily; pixelSize: 10 }
                    elide: Text.ElideRight
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.selectedIndex = index
                        root.copySelected()
                    }
                }
            }
        }
    }

    // keyboard navigation
    focus: shown
    Keys.onPressed: (event) => {
        if (!shown) return

        // down
        if (event.key === Qt.Key_Down) {
            if (root.entries.length > 0) {
              root.selectedIndex = (root.selectedIndex + 1) % root.entries.length
            }
            listView.positionViewAtIndex(root.selectedIndex, ListView.Contain)
            event.accepted = true
        // up
        } else if (event.key === Qt.Key_Up) {
            if (root.entries.length > 0)
              root.selectedIndex = root.selectedIndex <= 0
                ? root.entries.length - 1
                : root.selectedIndex - 1
            listView.positionViewAtIndex(root.selectedIndex, ListView.Contain)
            event.accepted = true
        // enter to copy
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.copySelected()
            event.accepted = true
            root.closeRequested()
        // escape to return back
        } else if (event.key === Qt.Key_Escape) {
            event.accepted = true
            root.closeRequested()
        }
    }
}
