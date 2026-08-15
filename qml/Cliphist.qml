import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    clip: true

    property bool shown: false
    property int selectedIndex: 0
    property var allEntries: [] // raw source of: { id, label, imagePath }
    property string searchQuery: ""
    property string deletingId: ""
    property string collapsingId: ""
    property bool imgFullPreview: false

    signal closeRequested()
    signal previewToggled(bool active)

    visible: shown
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 180 } }

    ListModel { id: listModel }

    onShownChanged: {
        if (shown) {
            refresh()
            searchQuery = ""
            searchInput.text = ""
            selectedIndex = 0
            searchInput.forceActiveFocus()
        }
    }

    onSearchQueryChanged: {
        rebuildFilteredModel()
        selectedIndex = 0
    }

    function rebuildFilteredModel() {
        listModel.clear()
        let list = searchQuery.length === 0 ? allEntries : allEntries.filter(e => e.label.toLowerCase().includes(searchQuery.toLowerCase()))
        if (list.length > 0) listModel.append(list)
    }

    function refresh() {
        listProc.running = false
        listProc.running = true
        listCountProc.running = false
        listCountProc.running = true
    }

    function copySelected() {
        if (listModel.count === 0) return
        let entry = listModel.get(selectedIndex)
        copyProc.command = ["sh", "-c", "cliphist decode " + entry.id + " | wl-copy"]
        copyProc.running = false
        copyProc.running = true
        root.closeRequested()
    }

    function deleteSelected() {
        if (listModel.count === 0) return
        let entry = listModel.get(selectedIndex)
        root.deletingId = entry.id
        deleteProc.command = ["sh", "-c", "printf '%s\\t' \"$1\" | cliphist delete", "_", entry.id]
        deleteProc.running = false
        deleteProc.running = true
        holdRedTimer.entryId = entry.id
        holdRedTimer.restart()
    }

    function imgFullPreviewSelected() {
        let entry = listModel.count > 0 ? listModel.get(root.selectedIndex) : null
        if (!entry || !entry.imagePath) return

        imgFullPreview = !imgFullPreview
        root.previewToggled(imgFullPreview)
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
        interval: 220  // matches the collapse animation on below
        repeat: false
        onTriggered: {
            let currentIdx = root.selectedIndex
            let savedContentY = listView.contentY

            let idx = -1
            for (let i = 0; i < listModel.count; i++) {
                if (listModel.get(i).id === entryId) { idx = i; break }
            }
            if (idx !== -1) listModel.remove(idx)
            root.allEntries = root.allEntries.filter(e => e.id !== entryId)

            root.deletingId = ""
            root.collapsingId = ""

            let newLength = listModel.count
            if (newLength === 0) root.selectedIndex = -1
            else if (currentIdx >= newLength) root.selectedIndex = newLength - 1
            else root.selectedIndex = currentIdx

            Qt.callLater(() => {
                let maxY = Math.max(0, listView.contentHeight - listView.height)
                listView.contentY = Math.min(savedContentY, maxY)
                listView.positionViewAtIndex(root.selectedIndex, ListView.Contain)
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
                root.allEntries = lines.map(line => {
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
                rebuildFilteredModel()
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
        radius: imgFullPreview ? 24 : 18
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
          visible: !imgFullPreview

          Text {
              text: "Clipboard History"
              color: Theme.fg
              font { family: Theme.fontFamily; pixelSize: 11; weight: 700 }
              Layout.alignment: Qt.AlignLeft
              Layout.leftMargin: 4
          }

          Text {
            id: listCountText
            property int total: 0
            text: (listModel.count === 0 ? 0 : root.selectedIndex + 1)
                   + " / " + listModel.count + " (" + total + ")"
            color: "#999999"
            font { family: Theme.fontFamily; pixelSize: 9; weight: 300 }
            Layout.alignment: Qt.AlignRight
            Layout.rightMargin: 6
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
            visible: !imgFullPreview

            TextInput {
                id: searchInput
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.fg
                font { family: Theme.fontFamily; pixelSize: 10 }
                clip: true
                readOnly: imgFullPreview

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
                        if (listModel.count > 0) {
                            root.selectedIndex = (root.selectedIndex + 1) % listModel.count
                        }
                        listView.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Up) {
                        if (listModel.count > 0)
                            root.selectedIndex = root.selectedIndex <= 0
                                ? listModel.count - 1
                                : root.selectedIndex - 1
                        listView.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.copySelected()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Escape) {
                        event.accepted = true
                        if (imgFullPreview) {
                            imgFullPreview = false
                            previewToggled(false)
                        } else {
                            root.closeRequested()
                        }
                    } else if (event.key === Qt.Key_Delete) {
                        root.deleteSelected()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Tab) {
                        console.log("Tab key clicked for clipboard image full preview")
                        root.imgFullPreviewSelected()
                        event.accepted = true
                    }
                }
            }
        }

        // image wrapped in item to align in center
        Item {
            width: parent.width
            height: parent.height
            visible: imgFullPreview

            Image {
                id: previewImage
                anchors.centerIn: parent
                width: parent.width - 15
                height: parent.height - 15
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                sourceSize: Qt.size(500, 500)
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                source: {
                    let entry = listModel.count > 0 ? listModel.get(root.selectedIndex) : null
                    return entry && entry.imagePath ? ("file://" + entry.imagePath) : ""
                }
            }
        }

        ListView {
            id: listView
            width: parent.width
            height: parent.height - 67
            clip: true
            model: listModel
            currentIndex: root.selectedIndex
            highlightFollowsCurrentItem: false
            highlightMoveDuration: 80
            visible: !imgFullPreview

            removeDisplaced: Transition { NumberAnimation { properties: "y"; duration: 150; easing.type: Easing.OutCubic } }

            delegate: Rectangle {
                width: listView.width
                height: model.id === root.collapsingId ? 5 : (model.imagePath ? 55 : 30)
                radius: 7
                color: model.id === root.deletingId ? "#e22d2d" : (index === root.selectedIndex ? "#313131" : "transparent")
                clip: true
                opacity: model.id === root.collapsingId ? 0 : 1
                scale: model.id === root.collapsingId ? 0.75 : 1

                Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                // image preview
                Image {
                    anchors.fill: parent
                    anchors.margins: 4
                    source: model.imagePath ? ("file://" + model.imagePath) : ""
                    visible: model.imagePath !== ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    sourceSize: Qt.size(80, 50)
                }

                // text label
                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8
                    text: model.label
                    visible: !model.imagePath && !imgFullPreview
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
}
