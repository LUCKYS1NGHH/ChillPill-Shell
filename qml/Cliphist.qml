import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    clip: true

    property bool shown: false
    property int selectedIndex: 0
    property var entries: [] // list of { id, label, imagePath }
    property string searchQuery: ""
    property string deletingId: ""
    property string collapsingId: ""
    property var filteredEntries: searchQuery.length === 0
        ? entries
        : entries.filter(e => e.label.toLowerCase().includes(searchQuery.toLowerCase()))

    signal closeRequested()

    width: 320
    height: 210
    visible: shown
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 180 } }

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

    function deleteSelected() {
        if (filteredEntries.length === 0) return
        let entry = filteredEntries[selectedIndex]
        root.deletingId = entry.id
        deleteProc.command = ["sh", "-c", "printf '%s\\t' \"$1\" | cliphist delete", "_", entry.id]
        deleteProc.running = false
        deleteProc.running = true
        holdRedTimer.entryId = entry.id
        holdRedTimer.restart()
    }

    Timer {
        id: holdRedTimer
        property string entryId: ""
        interval: 160
        repeat: false
        onTriggered: {
            root.collapsingId = entryId
            removeTimer.entryId = entryId
            removeTimer.restart()
        }
    }

    Timer {
        id: removeTimer
        property string entryId: ""
        interval: 220   // matches the collapse animation below
        repeat: false
        onTriggered: {
            let currentIdx = root.selectedIndex
            let savedContentY = listView.contentY
            root.entries = root.entries.filter(e => e.id !== entryId)
            root.deletingId = ""
            root.collapsingId = ""
            let newLength = filteredEntries.length
            if (newLength === 0) selectedIndex = -1
            else if (currentIdx >= newLength) selectedIndex = newLength - 1
            else selectedIndex = currentIdx
            Qt.callLater(() => {
                let maxY = Math.max(0, listView.contentHeight - listView.height)
                listView.contentY = Math.min(savedContentY, maxY)
            })
        }
    }

    Process {
        id: listProc
        command: ["bash", "-c", "/usr/share/chillpill-shell/scripts/cliphist-img.sh"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.split("\n").filter(l => l.length > 0)
                root.entries = lines.map(line => {
                    let tabIdx = line.indexOf("\t")
                    let id = line.substring(0, tabIdx)
                    let rest = line.substring(tabIdx + 1)

                    let nullIdx = rest.indexOf("\x00")
                    if (nullIdx !== -1) {
                        let label = rest.substring(0, nullIdx)
                        let iconPart = rest.substring(nullIdx + 1)
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
        id: deleteProc
        running: false
        onRunningChanged: if (!running) {
            listCountProc.running = false
            listCountProc.running = true
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
                    } else if (event.key === Qt.Key_Delete) {
                        root.deleteSelected()
                        event.accepted = true
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
            highlightFollowsCurrentItem: false
            highlightMoveDuration: 80

            removeDisplaced: Transition { NumberAnimation { properties: "y"; duration: 150; easing.type: Easing.OutCubic } } 

            delegate: Rectangle {
                width: listView.width
                height: modelData.id === root.collapsingId ? 5 : (modelData.imagePath ? 50 : 28)
                radius: 7
                color: modelData.id === root.deletingId ? "#e22d2d" : (index === root.selectedIndex ? "#313131" : "transparent")
                clip: true
                opacity: modelData.id === root.collapsingId ? 0 : 1
                scale: modelData.id === root.collapsingId ? 0.75 : 1

                Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                // image preview
                Image {
                    anchors.fill: parent
                    anchors.margins: 4
                    source: modelData.imagePath ? ("file://" + modelData.imagePath) : ""
                    visible: modelData.imagePath !== ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    sourceSize: Qt.size(80, 50)
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
