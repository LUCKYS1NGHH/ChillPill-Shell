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
    property var markedIds: []  // ids picked for multi select, deleted together
    property string markAnchorId: ""  // id the Shift+Up/Down range grows from
    property var deletingIds: []  // ids flashing red before they leave the list
    property var deletingBatch: []  // ids of the delete currently in flight
    property var collapsingIds: []  // ids animating out right before removal
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
            clearMarks()
            searchInput.forceActiveFocus()
        }
    }

    onSearchQueryChanged: {
        rebuildFilteredModel()
        selectedIndex = 0
    }

    onFullPreviewChanged: {
        syncPreviewContent()
        // when leaving the preview, hand keyboard control back to the search box
        // (matters once the preview text can hold focus for selection)
        if (!fullPreview) searchInput.forceActiveFocus()
    }

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

    function isMarked(id) {
        return root.markedIds.indexOf(id) !== -1
    }

    function isDeleting(id) {
        return root.deletingIds.indexOf(id) !== -1
    }

    function isCollapsing(id) {
        return root.collapsingIds.indexOf(id) !== -1
    }

    function clearMarks() {
        root.markedIds = []
        root.markAnchorId = ""
    }

    // Shift+Space (or Ctrl/Shift+click) marks/unmarks a single item
    function toggleMarkAt(index) {
        if (index < 0 || index >= listModel.count) return
        let id = listModel.get(index).id
        root.markAnchorId = id
        root.markedIds = root.isMarked(id) ? root.markedIds.filter(x => x !== id)
                                          : root.markedIds.concat([id])
    }

    // the row the marked range grows from, kept as an id so it survives
    // list rebuilds (search, removals), resolved on demand
    function markAnchorIndex() {
        if (root.markAnchorId !== "") {
            for (let i = 0; i < listModel.count; i++) {
                if (listModel.get(i).id === root.markAnchorId) return i
            }
        }
        return root.selectedIndex
    }

    // Shift+Up/Down: grow/shrink the marked range, editor style.
    // only in the list, in the full preview Up/Down can jump over items of the
    // other type (separatePreviewTabTypes), a range would swallow unrelated rows
    function extendMark(dir) {
        if (listModel.count === 0) return
        // the first Shift+<arrow> turns the highlighted row into the range start
        if (root.markAnchorId === "" && root.selectedIndex >= 0) {
            root.markAnchorId = listModel.get(root.selectedIndex).id
        }
        let anchor = root.markAnchorIndex()
        let to = root.selectedIndex + dir
        if (to < 0 || to >= listModel.count) return

        root.selectedIndex = to
        let ids = []
        let lo = Math.min(anchor, to)
        let hi = Math.max(anchor, to)
        for (let i = lo; i <= hi; i++) ids.push(listModel.get(i).id)
        root.markedIds = ids

        listView.positionViewAtIndex(to, ListView.Contain)
    }

    function copySelected() {
        if (listModel.count === 0) return
        let entry = listModel.get(selectedIndex)
        console.log("cliphist entry id:", entry.id)
        copyProc.command = ["sh", "-c", "cliphist decode " + entry.id + " | wl-copy"]
        copyProc.startDetached()
        root.closeRequested()
    }

    // cliphist ids are plain numbers, some versions use "b64:<hash>" for binary
    // entries, anything outside this set never reaches a shell
    function safeIds(ids) {
        let out = []
        for (let i = 0; i < ids.length; i++) {
            let id = String(ids[i])
            if (/^[A-Za-z0-9:+=._\/-]+$/.test(id)) out.push(id)
        }
        return out
    }

    // the whole batch goes through a single cliphist pipeline, ids are matched on
    // the "<id>\t" prefix so a short id can't drag a longer one with it
    function deleteCommand(ids) {
        let safe = root.safeIds(ids)
        if (safe.length === 0) return ""
        let patterns = []
        for (let i = 0; i < safe.length; i++) patterns.push("-e '^" + safe[i] + "\t'")
        return "cliphist list | grep -a " + patterns.join(" ") + " | cliphist delete"
    }

    // the image cache files the list previews are made of, cleaned up once the
    // delete actually ran, same opt-in the script had
    function removeImgCache(ids) {
        if (!Config.deleteCliphistImgCache) return
        let safe = root.safeIds(ids)
        if (safe.length === 0) return
        let dir = Quickshell.env("HOME") + "/.cache/chillpill-shell/cliphist-imgs"
        imgCacheProc.command = ["rm", "-f"].concat(safe.map(id => dir + "/" + id + ".png"))
        imgCacheProc.running = false
        imgCacheProc.running = true
    }

    // Del: the marked items go first, the highlighted one only when nothing is marked
    function deleteSelected() {
        if (listModel.count === 0 || root.selectedIndex < 0) return
        let ids = root.markedIds.length > 0
            ? root.markedIds.slice()
            : [listModel.get(root.selectedIndex).id]

        let cmd = root.deleteCommand(ids)
        if (cmd === "") return

        root.deletingIds = ids
        root.deletingBatch = ids

        deleteProc.command = ["sh", "-c", cmd]
        deleteProc.running = false
        deleteProc.running = true

        holdRedTimer.ids = ids
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

    function moveSelection(dir) {
        if (root.fullPreview) {
            if (Config.separatePreviewTabTypes) {
                let target = root.findAdjacentTypeIndex(dir, root.currentIsImage())
                if (target !== -1) {
                    root.previewSlideDir = dir
                    root.selectedIndex = target
                }
            } else if (listModel.count > 0) {
                root.previewSlideDir = dir
                if (dir === 1) {
                    root.selectedIndex = (root.selectedIndex + 1) % listModel.count
                } else {
                    root.selectedIndex = root.selectedIndex <= 0 ? listModel.count - 1 : root.selectedIndex - 1
                }
            }
        } else if (listModel.count > 0) {
            if (dir === 1) {
                root.selectedIndex = (root.selectedIndex + 1) % listModel.count
            } else {
                root.selectedIndex = root.selectedIndex <= 0 ? listModel.count - 1 : root.selectedIndex - 1
            }
        }
        listView.positionViewAtIndex(root.selectedIndex, ListView.Contain)
    }

    // Esc: exit the full preview first, then drop the multi select marks,
    // only then request closing the bar.
    function handleCloseKey() {
        if (root.fullPreview) {
            root.fullPreview = false
            root.previewToggled(false)
        } else if (root.markedIds.length > 0) {
            root.clearMarks()
        } else {
            root.closeRequested()
        }
    }

    // Shared keyboard shortcuts so they keep working whether the search box
    // or the (focused) preview text holds the active focus.
    function onShortcutPressed(event) {
        if (event.key === Qt.Key_Down) {
            if (event.modifiers & Qt.ShiftModifier && !root.fullPreview) root.extendMark(1)
            else root.moveSelection(1)
            event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            if (event.modifiers & Qt.ShiftModifier && !root.fullPreview) root.extendMark(-1)
            else root.moveSelection(-1)
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.copySelected()
            event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
            root.handleCloseKey()
            event.accepted = true
        } else if (event.key === Qt.Key_Delete) {
            root.deleteSelected()
            event.accepted = true
        } else if (event.key === Qt.Key_Space) {
            // plain Space still types into the search box, Shift+Space marks
            if (event.modifiers & Qt.ShiftModifier) {
                root.toggleMarkAt(root.selectedIndex)
                event.accepted = true
            }
        } else if (event.key === Qt.Key_Tab) {
            console.log("Tab key clicked for clipboard full preview")
            root.fullPreviewSelected()
            event.accepted = true
        }
    }

    Timer {
        id: holdRedTimer
        property var ids: []
        interval: 160
        repeat: false
        onTriggered: {
            root.collapsingIds = ids
            removeTimer.ids = ids
            removeTimer.restart()
        }
    }

    Timer {
        id: removeTimer
        property var ids: []
        interval: 220
        repeat: false
        onTriggered: {
            let batch = ids
            let currentIdx = root.selectedIndex
            let savedContentY = listView.contentY

            let wasPreviewing = root.fullPreview
            let wasImage = root.currentIsImage()

            // collect the rows first, then drop them last index first so the
            // earlier indices stay valid while the model shrinks
            let indices = []
            for (let i = 0; i < listModel.count; i++) {
                if (batch.indexOf(listModel.get(i).id) !== -1) indices.push(i)
            }
            for (let i = indices.length - 1; i >= 0; i--) listModel.remove(indices[i])
            root.allEntries = root.allEntries.filter(e => batch.indexOf(e.id) === -1)

            root.deletingIds = []
            root.collapsingIds = []
            root.markedIds = root.markedIds.filter(id => batch.indexOf(id) === -1)

            // land on the row the removed block started at when the cursor itself
            // was deleted, otherwise keep the cursor on the same item it was on
            let landed = indices.length > 0 && indices.indexOf(currentIdx) !== -1
                ? indices[0]
                : currentIdx - indices.filter(i => i < currentIdx).length

            let newLength = listModel.count
            if (newLength === 0) root.selectedIndex = -1
            else root.selectedIndex = Math.max(0, Math.min(landed, newLength - 1))

            // if in full preview with separated types, make sure landed index matches the preview type
            if (wasPreviewing && Config.separatePreviewTabTypes && root.selectedIndex !== -1) {
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
        onExited: (code) => {
            if (code === 0) root.removeImgCache(root.deletingBatch)
        }
    }

    // drops the cached preview images of the deleted binary entries
    Process {
        id: imgCacheProc
        running: false
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

                Keys.onPressed: (event) => root.onShortcutPressed(event)
            }

            // multi select state / hint, hidden as soon as the query gets in the way
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                visible: !fullPreview && searchInput.text.length === 0 && root.markedIds.length === 0
                text: " / [SPACE] to multi-select"
                color: Theme.fg4
                font { family: Theme.fontFamily; pixelSize: 9 }
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                visible: !fullPreview && root.markedIds.length > 0
                text: root.markedIds.length + " marked • Del removes"
                color: Theme.fg3
                font { family: Theme.fontFamily; pixelSize: 8; weight: 600 }
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
                        readonly property bool currentDeleting: root.isDeleting(currentEntryId)
                        readonly property bool currentCollapsing: root.isCollapsing(currentEntryId)
                        // brief "Copied" toast shown when text is copied from the preview
                        property bool copiedFlash: false

                        function flashCopied() {
                            copiedFlash = true
                            copiedFlashTimer.restart()
                        }

                        Component.onCompleted: {
                            previewContent.slideY = root.previewSlideDir * 26
                            contentSlideAnim.restart()
                        }

                        Timer {
                            id: copiedFlashTimer
                            interval: 900
                            repeat: false
                            onTriggered: copiedFlash = false
                        }

                        // quick copy: copy once a mouse selection has settled (release)
                        Timer {
                            id: quickCopyTimer
                            interval: 300
                            repeat: false
                            onTriggered: {
                                if (textPreview.selectedText.length > 0) {
                                    textPreview.copy()
                                    flashCopied()
                                }
                            }
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

                                opacity: currentCollapsing ? 0 : (status === Image.Ready ? 1 : 0)
                                scale: currentCollapsing ? 0.8 : 1
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

                                        opacity: currentCollapsing ? 0 : (textReady ? 0.8 : 0)
                                        scale: currentCollapsing ? 0.8 : 1
                                        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                    }

                                    // TextEdit is used instead of Text so the preview text
                                    // can be mouse-selected (and copied) in the full preview.
                                    TextEdit {
                                        id: textPreview
                                        text: root.previewText
                                        color: Theme.fg
                                        font { family: Theme.fontFamily; pixelSize: 12 }
                                        wrapMode: TextEdit.NoWrap
                                        textFormat: TextEdit.PlainText
                                        readOnly: true
                                        selectByMouse: true
                                        activeFocusOnTab: false
                                        // keep Esc/Tab/arrows/etc. working while the preview text holds focus,
                                        // and intercept copy (Ctrl+C / Ctrl+Insert) to show the "Copied" toast
                                        Keys.onShortcutOverride: (event) => {
                                            if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_C || event.key === Qt.Key_Insert)) {
                                                event.accepted = true
                                            }
                                        }
                                        Keys.onPressed: (event) => {
                                            if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_C || event.key === Qt.Key_Insert)) {
                                                if (textPreview.selectedText.length > 0) {
                                                    textPreview.copy()
                                                    flashCopied()
                                                }
                                                event.accepted = true
                                            } else {
                                                root.onShortcutPressed(event)
                                            }
                                        }
                                        // quick copy: schedule an auto-copy once the selection stops changing
                                        onSelectedTextChanged: {
                                            if (textPreview.selectedText.length > 0) {
                                                quickCopyTimer.restart()
                                            }
                                        }
                                        // TextEdit doesn't auto-size like Text does,
                                        // so track its content size explicitly.
                                        width: implicitWidth
                                        height: implicitHeight

                                        opacity: currentCollapsing ? 0 : (textReady ? 1 : 0)
                                        scale: currentCollapsing ? 0.8 : 1
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
                            // dismiss a lingering "Copied" toast when navigating away
                            copiedFlash = false
                            copiedFlashTimer.stop()
                            quickCopyTimer.stop()
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
                            opacity: currentDeleting ? 0.70 : 0
                            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        }

                        // "Deleted" pop text
                        Text {
                            anchors.centerIn: parent
                            text: "Deleted"
                            color: "white"
                            font { family: Theme.fontFamily; pixelSize: 14; weight: 600 }
                            opacity: currentDeleting ? 1 : 0
                            scale: currentDeleting ? 1 : 0.80
                            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                        }

                        // "Copied" badge, shown briefly when text is copied from the preview.
                        // Padded pill background keeps it readable over multi-line text.
                        Item {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 30
                            width: copiedLabel.implicitWidth + 18
                            height: copiedLabel.implicitHeight + 10
                            opacity: copiedFlash ? 1 : 0
                            scale: copiedFlash ? 1 : 0.85
                            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }

                            Rectangle {
                                anchors.fill: parent
                                radius: height / 2
                                color: Theme.bg1
                            }

                            Text {
                                id: copiedLabel
                                anchors.centerIn: parent
                                text: "Copied"
                                color: "white"
                                font { family: Theme.fontFamily; pixelSize: 12; weight: 600 }
                            }
                        }

                        // multi select chip, the list itself is hidden in the full preview
                        // so this is the only hint of how many items are marked
                        Item {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 8
                            visible: root.markedIds.length > 0
                            width: markedLabel.implicitWidth + 18
                            height: markedLabel.implicitHeight + 10
                            opacity: currentCollapsing ? 0 : 1
                            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                            Rectangle {
                                anchors.fill: parent
                                radius: height / 2
                                color: Theme.bg1
                            }

                            Text {
                                id: markedLabel
                                anchors.centerIn: parent
                                text: root.markedIds.length + " marked • Del removes"
                                color: Theme.fg3
                                font { family: Theme.fontFamily; pixelSize: 9 }
                            }
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
                height: root.isCollapsing(model.id) ? 5 : (model.imagePath ? 55 : 30)
                radius: 7
                color: root.isDeleting(model.id) ? Theme.deleting : (index === root.selectedIndex ? Theme.focusBg1 : (root.isMarked(model.id) ? Theme.bg4 : "transparent"))
                clip: true
                opacity: root.isCollapsing(model.id) ? 0 : 1
                scale: root.isCollapsing(model.id) ? 0.75 : 1

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

                // mark tick for multi selected items, sits in the padding ring
                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: 3
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.isMarked(model.id) && !root.isDeleting(model.id)
                    width: 2
                    height: model.imagePath ? 24 : 12
                    radius: 1
                    color: Theme.accent
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
                    onClicked: (mouse) => {
                        root.selectedIndex = index
                        // Ctrl/Shift+click marks instead of copying
                        if (mouse.modifiers & (Qt.ControlModifier | Qt.ShiftModifier)) root.toggleMarkAt(index)
                        else root.copySelected()
                    }
                }
            }
        }
    }
}
