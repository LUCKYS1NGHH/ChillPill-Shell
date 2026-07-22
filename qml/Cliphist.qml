import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    clip: true

    property bool shown: false
    property int selectedIndex: 0
    property string searchQuery: ""
    property string deletingId: ""

    signal closeRequested()

    width: 320
    height: 210
    visible: shown
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 150 } }

    ListModel { id: entriesModel }
    ListModel { id: filteredModel }

    function rebuildFiltered() {
        filteredModel.clear()
        for (let i = 0; i < entriesModel.count; i++) {
            let e = entriesModel.get(i)
            if (searchQuery.length === 0 || e.label.toLowerCase().includes(searchQuery.toLowerCase()))
                filteredModel.append({ id: e.id, label: e.label, imagePath: e.imagePath })
        }
        selectedIndex = 0
    }

    onSearchQueryChanged: rebuildFiltered()

    onShownChanged: {
        if (shown) {
            refresh()
            searchQuery = ""
            searchInput.text = ""
            selectedIndex = 0
            searchInput.forceActiveFocus()
        }
    }

    function refresh() {
        listProc.running = false
        listProc.running = true
        listCountProc.running = false
        listCountProc.running = true
    }

    function copySelected() {
        if (filteredModel.count === 0) return
        let entry = filteredModel.get(selectedIndex)
        copyProc.command = ["sh", "-c", "cliphist decode " + entry.id + " | wl-copy"]
        copyProc.running = false
        copyProc.running = true
        root.closeRequested()
    }

    function deleteSelected() {
        if (filteredModel.count === 0) return
        let entry = filteredModel.get(selectedIndex)

        root.deletingId = entry.id

        deleteProc.command = ["sh", "-c", "printf '%s\\t' \"$1\" | cliphist delete", "_", entry.id]
        deleteProc.running = false
        deleteProc.running = true

        deleteFlashTimer.entryId = entry.id
        deleteFlashTimer.restart()
    }

    Timer {
        id: deleteFlashTimer
        property string entryId: ""
        interval: 120
        repeat: false
        onTriggered: {
            for (let i = 0; i < entriesModel.count; i++) {
                if (entriesModel.get(i).id === entryId) { entriesModel.remove(i); break }
            }
            for (let i = 0; i < filteredModel.count; i++) {
                if (filteredModel.get(i).id === entryId) { filteredModel.remove(i); break }
            }
            root.deletingId = ""
            if (selectedIndex >= filteredModel.count && selectedIndex > 0)
                selectedIndex = filteredModel.count - 1
        }
    }

    Process {
        id: listProc
        command: ["bash", "-c", "/usr/share/chillpill-shell/scripts/cliphist-img.sh"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.split("\n").filter(l => l.length > 0)
                entriesModel.clear()
                lines.forEach(line => {
                    let tabIdx = line.indexOf("\t")
                    let id = line.substring(0, tabIdx)
                    let rest = line.substring(tabIdx + 1)

                    let nullIdx = rest.indexOf("\x00")
                    let label = rest, imgPath = ""
                    if (nullIdx !== -1) {
                        label = rest.substring(0, nullIdx)
                        let iconPart = rest.substring(nullIdx + 1)
                        imgPath = iconPart.split("\x1f")[1] || ""
                    }
                    entriesModel.append({ id, label, imagePath: imgPath })
                })
                rebuildFiltered()
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
            text: (filteredModel.count === 0 ? 0 : root.selectedIndex + 1)
                   + " / " + filteredModel.count + " (" + total + ")"
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
                        if (filteredModel.count > 0) {
                            root.selectedIndex = (root.selectedIndex + 1) % filteredModel.count
                        }
                        listView.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Up) {
                        if (filteredModel.count > 0)
                            root.selectedIndex = root.selectedIndex <= 0
                                ? filteredModel.count - 1
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
            model: filteredModel
            currentIndex: root.selectedIndex
            highlightFollowsCurrentItem: false
            highlightMoveDuration: 80

            removeDisplaced: Transition { NumberAnimation { properties: "y"; duration: 200; easing.type: Easing.OutCubic } }

            delegate: Rectangle {
                width: listView.width
                height: id === root.deletingId ? 5 : imagePath ? 50 : 28
                radius: 7
                color: id === root.deletingId ? "#e93a3a" : index === root.selectedIndex ? "#313131" : "transparent"
                clip: true
                opacity: id === root.deletingId ? 0 : 1
                scale: id === root.deletingId ? 0.75 : 1

                Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                // image preview
                Image {
                    anchors.fill: parent
                    anchors.margins: 4
                    source: imagePath ? ("file://" + imagePath) : ""
                    visible: imagePath !== ""
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
                    text: label
                    visible: !imagePath
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
