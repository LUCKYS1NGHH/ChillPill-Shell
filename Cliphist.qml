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
    property string searchQuery: ""
    property var filteredEntries: searchQuery.length === 0
        ? entries
        : entries.filter(e => e.label.toLowerCase().includes(searchQuery.toLowerCase()))

    signal closeRequested()

    width: 320
    height: 210
    visible: shown
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 150 } }

    onShownChanged: {
        if (shown) {
            refresh()
            searchQuery = ""
            searchInput.text = ""
            selectedIndex = 0
            searchInput.forceActiveFocus()
        }
    }

    onFilteredEntriesChanged: {
        selectedIndex = 0
    }

    function refresh() {
        listProc.running = false
        listProc.running = true
        listCountProc.running = false
        listCountProc.running = true
    }

    function copySelected() {
        if (filteredEntries.length === 0) return
        let entry = filteredEntries[selectedIndex]
        copyProc.command = ["sh", "-c", "cliphist decode " + entry.id + " | wl-copy"]
        copyProc.running = false
        copyProc.running = true
        root.closeRequested()
    }

    Process {
        id: listProc
        command: ["bash", "-c", "~/.config/quickshell/cliphist-img.sh"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.split("\n").filter(l => l.length > 0)
                root.entries = lines.map(line => {
                    let tabIdx = line.indexOf("\t")
                    let id = line.substring(0, tabIdx)
                    let rest = line.substring(tabIdx + 1)

                    // rofi format is label\x00icon\x1f/path
                    let nullIdx = rest.indexOf("\x00")
                    if (nullIdx !== -1) {
                        let label = rest.substring(0, nullIdx)
                        let iconPart = rest.substring(nullIdx + 1)  // "icon\x1f/path"
                        let imgPath = iconPart.split("\x1f")[1] || ""
                        return { id, label, imagePath: imgPath }
                    }

                    return { id, label: rest, imagePath: "" }
                })
            }
        }
    }

    Process {
      id: listCountProc
      command: ["sh", "-c", "cliphist list | wc -l"]
      running: false
      stdout: StdioCollector {
        onStreamFinished: {
          listCountText.total = this.text.trim();
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

        RowLayout {
          width: parent.width

          Text {
              text: "Clipboard History"
              color: Theme.fg
              font { family: Theme.fontFamily; pixelSize: 11; weight: 700 }
              anchors.left: parent.left
              anchors.leftMargin: 4
          }

          Text {
            id: listCountText
            property int total: 0
            text: (root.filteredEntries.length === 0 ? 0 : root.selectedIndex + 1)
                   + " / " + root.filteredEntries.length + " (" + total + ")"
            color: "#999999"
            font { family: Theme.fontFamily; pixelSize: 8; weight: 300 }
            anchors.right: parent.right
            anchors.rightMargin: 6
          }
        }

        // search box
        Rectangle {
            width: parent.width
            height: 26
            radius: 6
            color: "#252525"
            border.color: searchInput.activeFocus ? "#555" : "#333"
            border.width: 1

            TextInput {
                id: searchInput
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.fg
                font { family: Theme.fontFamily; pixelSize: 10 }
                clip: true

                onTextChanged: root.searchQuery = text

                Text {
                    text: "search clips..."
                    color: "#666"
                    font: searchInput.font
                    visible: searchInput.text.length === 0
                    anchors.verticalCenter: parent.verticalCenter
                }

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Down) {
                        if (root.filteredEntries.length > 0) {
                            root.selectedIndex = (root.selectedIndex + 1) % root.filteredEntries.length
                        }
                        listView.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Up) {
                        if (root.filteredEntries.length > 0)
                            root.selectedIndex = root.selectedIndex <= 0
                                ? root.filteredEntries.length - 1
                                : root.selectedIndex - 1
                        listView.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.copySelected()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Escape) {
                        event.accepted = true
                        root.closeRequested()
                    }
                }
            }
        }

        ListView {
            id: listView
            width: parent.width
            height: parent.height - 65
            clip: true
            model: root.filteredEntries
            currentIndex: root.selectedIndex
            highlightMoveDuration: 80

            delegate: Rectangle {
                width: listView.width
                height: modelData.imagePath ? 50 : 28
                radius: 7
                color: index === root.selectedIndex ? "#313131" : "transparent"

                // image preview
                Image {
                    anchors.fill: parent
                    anchors.margins: 4
                    source: modelData.imagePath ? ("file://" + modelData.imagePath) : ""
                    visible: modelData.imagePath !== ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }

                // text label
                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    text: modelData.label
                    visible: !modelData.imagePath
                    color: Theme.fg
                    font { family: Theme.fontFamily; pixelSize: 9 }
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
}
