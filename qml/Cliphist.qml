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
    property bool fullPreview: false
    property int previewSlideDir: 1  // 1 = down/next, -1 = up/prev
    property string previewText: ""  // full decoded content for text preview
    property string previewTargetId: ""  // entry id the in-flight decode is for
    property bool previewReady: false  // true when previewText matches previewTargetId

    signal closeRequested()
    signal previewToggled(bool active)

    visible: shown
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 180 } }
    scale: shown ? 1 : 0.96
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    transformOrigin: Item.Center

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

    onFullPreviewChanged: syncPreviewContent()

    onSelectedIndexChanged: {
        if (fullPreview) syncPreviewContent()
    }

    function syncPreviewContent() {
        if (!root.fullPreview || listModel.count === 0 || root.selectedIndex < 0) {
            decodeProc.running = false
            root.previewText = ""
            root.previewReady = false
            return
        }
        let entry = listModel.get(root.selectedIndex)
        if (entry && !entry.imagePath) {
            root.loadPreviewText(entry.id)
        } else {
            decodeProc.running = false
            root.previewText = ""
            root.previewReady = false
        }
    }

    function loadPreviewText(id) {
        root.previewTargetId = id
        root.previewReady = false
        decodeProc.command = ["cliphist", "decode", id]
        decodeProc.running = false
        decodeProc.running = true
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
        console.log("cliphist entry id:", entry.id)
        copyProc.command = ["sh", "-c", "cliphist decode " + entry.id + " | wl-copy"]
        copyProc.startDetached()
        root.closeRequested()
    }

    function deleteSelected() {
        if (listModel.count === 0) return
        let entry = listModel.get(selectedIndex)
        root.deletingId = entry.id

        deleteProc.command = ["sh", "-c", "/usr/share/chillpill-shell/scripts/cliphist-img.sh delete \"$1\" \"$2\"", "_", entry.id, Config.deleteCliphistImgCache]
        deleteProc.running = false
        deleteProc.running = true

        holdRedTimer.entryId = entry.id
        holdRedTimer.restart()
    }

    function currentIsImage() {
        let idx = root.selectedIndex
        if (idx < 0 || idx >= listModel.count) return false
        return !!listModel.get(idx).imagePath
    }

    function fullPreviewSelected() {
        let entry = listModel.count > 0 ? listModel.get(root.selectedIndex) : null
        if (!entry) return

        fullPreview = !fullPreview
        root.previewToggled(fullPreview)
    }

    function findAdjacentTypeIndex(direction, wantImage) {
        if (listModel.count === 0) return -1
        let idx = root.selectedIndex
        for (let i = 0; i < listModel.count; i++) {
            idx = (idx + direction + listModel.count) % listModel.count
            let e = listModel.get(idx)
            if (wantImage ? !!e.imagePath : !e.imagePath) return idx
        }
        return -1
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
        interval: 220
        repeat: false
        onTriggered: {
            let currentIdx = root.selectedIndex
            let savedContentY = listView.contentY

            let wasPreviewing = root.fullPreview
            let wasImage = root.currentIsImage()

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

            // if in full preview, make sure landed index actually matches the preview type
            if (wasPreviewing && root.selectedIndex !== -1) {
                let entry = listModel.get(root.selectedIndex)
                if (!entry || (wasImage ? !entry.imagePath : !!entry.imagePath)) {
                    let sameTypeIdx = root.findAdjacentTypeIndex(root.previewSlideDir, wasImage)
                    if (sameTypeIdx !== -1) {
                        root.selectedIndex = sameTypeIdx
                    } else {
                        root.fullPreview = false
                        root.previewToggled(false)
                    }
                }
            }

            // refresh decoded text even if selectedIndex value didn't change,
            // otherwise the preview keeps showing the deleted entry's text
            if (root.fullPreview) {
                if (!wasImage) {
                    root.previewText = ""
                    root.previewReady = false
                }
                root.syncPreviewContent()
            }

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

    Process {
        id: decodeProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                // ignore stale output if the process was restarted for another entry
                if (root.previewTargetId === decodeProc.command[2]) {
                    root.previewText = this.text
                    root.previewReady = true
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: fullPreview ? 24 : 18
        color: Theme.bgD1
        border.color: Theme.borderBg2
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
          visible: !fullPreview

          Text {
              text: "Clipboard Manager"
              color: Theme.fg2
              font { family: Theme.fontFamily; pixelSize: 11; weight: 700 }
              Layout.alignment: Qt.AlignLeft
              Layout.leftMargin: 4
          }

          Text {
            id: listCountText
            property int total: 0
            text: (listModel.count === 0 ? 0 : root.selectedIndex + 1)
                   + " / " + listModel.count + " (" + total + ")"
            color: Theme.fg4
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
            color: Theme.bg4
            border.color: searchInput.activeFocus ? Theme.borderBgFocus : Theme.borderBg
            border.width: 1
            visible: !fullPreview

            TextInput {
                id: searchInput
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.fg
                font { family: Theme.fontFamily; pixelSize: 10 }
                clip: true
                readOnly: fullPreview

                onTextChanged: root.searchQuery = text

                Text {
                    text: "search clips..."
                    color: Theme.fg3
                    font: searchInput.font
                    visible: searchInput.text.length === 0
                    anchors.verticalCenter: parent.verticalCenter
                }

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Down) {
                        if (fullPreview) {
                            let next = root.findAdjacentTypeIndex(1, root.currentIsImage())
                            if (next !== -1) {
                                root.previewSlideDir = 1
                                root.selectedIndex = next
                            }
                        } else if (listModel.count > 0) {
                            root.selectedIndex = (root.selectedIndex + 1) % listModel.count
                        }
                        listView.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Up) {
                        if (fullPreview) {
                            let prev = root.findAdjacentTypeIndex(-1, root.currentIsImage())
                            if (prev !== -1) {
                                root.previewSlideDir = -1
                                root.selectedIndex = prev
                            }
                        } else if (listModel.count > 0) {
                            root.selectedIndex = root.selectedIndex <= 0 ? listModel.count - 1 : root.selectedIndex - 1
                        }
                        listView.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.copySelected()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Escape) {
                        event.accepted = true
                        if (fullPreview) {
                            fullPreview = false
                            previewToggled(false)
                        } else {
                            root.closeRequested()
                        }
                    } else if (event.key === Qt.Key_Delete) {
                        root.deleteSelected()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Tab) {
                        console.log("Tab key clicked for clipboard full preview")
                        root.fullPreviewSelected()
                        event.accepted = true
                    }
                }
            }
        }

        // full preview (image or text), wrapped in item to align in center
        Item {
            width: parent.width
            height: parent.height
            visible: fullPreview

            Loader {
                anchors.fill: parent
                active: fullPreview
                asynchronous: true

                sourceComponent: Component {
                    Item {
                        anchors.fill: parent

                        readonly property string currentEntryId: {
                            let idx = root.selectedIndex
                            if (idx < 0 || idx >= listModel.count) return ""
                            return listModel.get(idx).id
                        }
                        readonly property bool currentIsImage: {
                            let idx = root.selectedIndex
                            if (idx < 0 || idx >= listModel.count) return false
                            return !!listModel.get(idx).imagePath
                        }
                        readonly property string lineNumbers: {
                            let content = root.previewText
                            if (content !== "" && content.endsWith("\n")) content = content.slice(0, -1)
                            let n = content.length === 0 ? 1 : content.split("\n").length
                            let out = ""
                            for (let i = 1; i <= n; i++) {
                                if (i > 1) out += "\n"
                                out += i
                            }
                            return out
                        }
                        readonly property int lineNumWidth: {
                            let content = root.previewText
                            if (content !== "" && content.endsWith("\n")) content = content.slice(0, -1)
                            let n = content.split("\n").length
                            let digits = Math.max(1, String(n).length)
                            return digits * 7 + 12
                        }
                        readonly property bool textReady: root.previewReady && root.previewTargetId === currentEntryId

                        Component.onCompleted: {
                            previewContent.slideY = root.previewSlideDir * 26
                            contentSlideAnim.restart()
                        }

                        // sliding container for both preview types
                        Item {
                            id: previewContent
                            anchors.fill: parent

                            property real slideY: 0
                            transform: Translate { y: previewContent.slideY }

                            // image preview
                            Image {
                                id: previewImage
                                width: parent.width - 15
                                height: parent.height - 25
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 25
                                anchors.horizontalCenter: parent.horizontalCenter
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                sourceSize: Qt.size(500, 500)
                                cache: false
                                visible: currentIsImage

                                opacity: currentEntryId === root.collapsingId ? 0 : (status === Image.Ready ? 1 : 0)
                                scale: currentEntryId === root.collapsingId ? 0.8 : 1
                                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                                source: currentIsImage ? ("file://" + listModel.get(root.selectedIndex).imagePath) : ""
                            }

                            // text preview
                            Flickable {
                                id: textFlick
                                visible: !currentIsImage
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 12
                                anchors.topMargin: 12
                                anchors.bottomMargin: 25
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                flickableDirection: Flickable.HorizontalAndVerticalFlick
                                contentWidth: codeArea.implicitWidth
                                contentHeight: codeArea.implicitHeight

                                Row {
                                    id: codeArea
                                    spacing: 8

                                    Text {
                                        id: lineNumText
                                        width: lineNumWidth
                                        text: lineNumbers
                                        color: Theme.fg6
                                        font { family: Theme.fontFamily; pixelSize: 12 }
                                        horizontalAlignment: Text.AlignRight

                                        opacity: (currentEntryId === root.collapsingId) ? 0 : (textReady ? 0.8 : 0)
                                        scale: currentEntryId === root.collapsingId ? 0.8 : 1
                                        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                    }

                                    Text {
                                        id: textPreview
                                        text: root.previewText
                                        color: Theme.fg
                                        font { family: Theme.fontFamily; pixelSize: 12 }
                                        wrapMode: Text.NoWrap
                                        textFormat: Text.PlainText

                                        opacity: (currentEntryId === root.collapsingId) ? 0 : (textReady ? 1 : 0)
                                        scale: currentEntryId === root.collapsingId ? 0.8 : 1
                                        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                    }
                                }
                            }
                        }

                        onCurrentEntryIdChanged: {
                            textFlick.contentX = 0
                            textFlick.contentY = 0
                            previewContent.slideY = root.previewSlideDir * 26
                            contentSlideAnim.restart()
                        }

                        NumberAnimation {
                            id: contentSlideAnim
                            target: previewContent
                            property: "slideY"
                            to: 0
                            duration: 200
                            easing.type: Easing.OutCubic
                        }

                        // red tint flash on delete confirm
                        Rectangle {
                            anchors.fill: parent
                            anchors.bottomMargin: 26
                            radius: 15
                            color: Theme.deleting
                            opacity: currentEntryId === root.deletingId ? 0.70 : 0
                            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        }

                        // "Deleted" pop text
                        Text {
                            anchors.centerIn: parent
                            text: "Deleted"
                            color: "white"
                            font { family: Theme.fontFamily; pixelSize: 14; weight: 600 }
                            opacity: currentEntryId === root.deletingId ? 1 : 0
                            scale: currentEntryId === root.deletingId ? 1 : 0.80
                            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                        }

                        Text {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.margins: 2
                            text: (root.selectedIndex + 1) + " / " + listModel.count
                            color: Theme.fg4
                            font { family: Theme.fontFamily; pixelSize: 9; weight: 300 }
                        }
                    }
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
            visible: !fullPreview
            cacheBuffer: 0

            removeDisplaced: Transition { NumberAnimation { properties: "y"; duration: 150; easing.type: Easing.OutCubic } }

            delegate: Rectangle {
                width: listView.width
                height: model.id === root.collapsingId ? 5 : (model.imagePath ? 55 : 30)
                radius: 7
                color: model.id === root.deletingId ? Theme.deleting : (index === root.selectedIndex ? Theme.focusBg1 : "transparent")
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
                    cache: false
                }

                // text label
                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8
                    text: model.label
                    visible: !model.imagePath && !fullPreview
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