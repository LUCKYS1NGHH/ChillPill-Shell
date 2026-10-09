import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Widgets

Item {
    id: root
    clip: true

    property bool shown: false
    // Tab-toggled description of the selected app, expanded inside its row
    property bool descShown: false
    property int selectedIndex: 0
    property string searchQuery: ""
    property var appsCache: []

    // launch counts, persisted to ~/.cache so the most used apps sit on top
    property var usage: ({}) // desktop entry id -> launch count
    readonly property string usagePath: Quickshell.env("HOME") + "/.cache/chillpill-shell/app-usage.json"

    function usageCount(id) {
        const n = root.usage[id]
        return n ? n : 0
    }

    function recordUsage(id) {
        if (!id) return
        const u = Object.assign({}, root.usage)
        u[id] = (u[id] || 0) + 1
        root.usage = u
        usageFile.setText(JSON.stringify(u))
    }

    // ---- modes, picked off the first character of the query (rofi style) ----
    // ""     apps  filter the .desktop entries
    // "="    math  evaluate the expression, Enter copies the result
    // "?"    web   open the query in the default browser via xdg-open,
    //              Tab wraps the full search url over several lines
    // ">"    shell run the command, its output takes over the result list
    readonly property string mode: {
        const c = searchQuery.charAt(0)
        if (c === "=") return "math"
        if (c === "?") return "web"
        if (c === ">") return "shell"
        return "apps"
    }
    readonly property string modeArg: searchQuery.slice(1).trim()
    readonly property var calc: mode === "math" ? Calc.evaluate(modeArg) : null

    // ">" state: the command that produced the current output, its streams and
    // exit code. Matching against modeArg means editing the query drops back to
    // the command row without wiping the output of a finished run.
    property string shellCmd: ""
    property string shellOut: ""
    property string shellErr: ""
    property var shellExit: null
    readonly property bool shellBusy: shellProc.running
    readonly property string shellText: shellOut + shellErr
    readonly property bool shellShown: mode === "shell" && modeArg === shellCmd
        && (shellBusy || shellExit !== null)

    function webUrl(q) {
        const tpl = Config.webSearchUrl && Config.webSearchUrl.length > 0
            ? Config.webSearchUrl : "https://duckduckgo.com/?q=%s"
        const enc = encodeURIComponent(q)
        return tpl.indexOf("%s") >= 0 ? tpl.split("%s").join(enc) : tpl + enc
    }

    // the single row non-app modes put in the list (null = show nothing)
    readonly property var actionRow: {
        if (mode === "math") {
            if (modeArg === "") return { glyph: "", name: "type an expression", comment: "e.g. 12 * (3 + 4)", action: "none" }
            if (!calc.ok) return { glyph: "", name: modeArg, comment: calc.error, action: "none" }
            return { glyph: "", name: modeArg, comment: "= " + calc.text, action: "copy" }
        }
        if (mode === "web") {
            if (modeArg === "") return { glyph: "?", name: "search the web", comment: "type a query", action: "none" }
            return { glyph: "?", name: modeArg, comment: webUrl(modeArg), action: "web" }
        }
        if (modeArg === "") return { glyph: "", name: "type a command", comment: "output is shown in this list", action: "none" }
        return { glyph: "", name: modeArg, comment: shellBusy ? "running…" : "run in " + Config.defaultTerminal, action: "run" }
    }

    // what the list shows: apps, one action row, or nothing while the output
    // of a ">" command takes the list's place
    readonly property var results: mode === "apps" ? filteredApps
        : shellShown ? [] : (actionRow ? [actionRow] : [])

    Process {
        id: shellProc
        running: false
        stdout: StdioCollector { onStreamFinished: root.shellOut = this.text }
        stderr: StdioCollector { onStreamFinished: root.shellErr = this.text }
        onExited: (exitCode) => root.shellExit = exitCode
    }

    // atomicWrites renames into the cache dir, so make sure it exists first
    Process {
        id: usageDirProc
        command: ["mkdir", "-p", Quickshell.env("HOME") + "/.cache/chillpill-shell"]
    }

    FileView {
        id: usageFile
        path: root.usagePath
        onLoaded: {
            try {
                const d = JSON.parse(usageFile.text())
                root.usage = (d && typeof d === "object") ? d : {}
            } catch (e) {
                root.usage = {}
            }
        }
    }

    function runShell(cmd) {
        shellCmd = cmd
        shellOut = ""
        shellErr = ""
        shellExit = null
        shellProc.running = false
        shellProc.command = ["sh", "-c", cmd]
        shellProc.running = true
    }

    function runAction(row) {
        if (!row || row.action === "none") return
        if (row.action === "copy") {
            Quickshell.execDetached(["wl-copy", calc.text])
            closeRequested()
        } else if (row.action === "web") {
            Quickshell.execDetached(["xdg-open", webUrl(modeArg)])
            closeRequested()
        } else if (row.action === "run") {
            runShell(modeArg)
        }
    }

    signal closeRequested()

    width: 315

    property int rowHeight: 44
    property int rowSpacing: 2
    property int headerHeight: 15
    property int maxListHeight: 250

    // the pill, the row and the text fade all run OutCubic over this, so they stay in step
    readonly property int openDuration: 200

    readonly property int listHeight: root.results.length === 0
        ? root.rowHeight
        : Math.min(root.results.length * root.rowHeight + (root.results.length - 1) * root.rowSpacing, root.maxListHeight)
    readonly property int baseHeight: 12 + root.headerHeight + 8 + 30 + 8 + 12
    // output of a ">" command sizes its own panel, otherwise the description
    // opens inside its row so the spotlight keeps its height; the viewport
    // only stretches when a lone result is too short to hold the opened row
    readonly property int outputLines: root.shellText.length === 0
        ? 1 : root.shellText.split("\n").length
    readonly property int outputHeight: Math.min(Math.max(70, root.outputLines * 14 + 34), root.maxListHeight)
    readonly property int viewHeight: root.shellShown ? root.outputHeight
        : Math.max(root.listHeight, root.descShown && appList.currentItem ? appList.currentItem.height : 0)
    height: root.baseHeight + root.viewHeight
    Behavior on height { NumberAnimation { duration: root.openDuration; easing.type: Easing.OutCubic } }

    // open/close: fade + gentle scale that grows down from the top edge
    visible: opacity > 0
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    transformOrigin: Item.Top
    scale: shown ? 1 : 0.94
    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    // fuzzy ranks the tiers from matchApp(), best first
    property var filteredApps: {
        if (searchQuery.length === 0) {
            // most used first, then alphabetical
            let list = appsCache.slice()
            list.sort((a, b) => root.usageCount(b.entry.id) - root.usageCount(a.entry.id)
                || a.name.localeCompare(b.name))
            return list
        }
        const q = searchQuery.toLowerCase()
        if (Config.appLauncherFuzzySearch) {
            let scored = []
            for (let i = 0; i < appsCache.length; i++) {
                const m = matchApp(q, appsCache[i])
                if (m) scored.push({ app: appsCache[i], tier: m.tier, score: m.score })
            }
            scored.sort((a, b) => a.tier - b.tier || b.score - a.score
                || root.usageCount(b.app.entry.id) - root.usageCount(a.app.entry.id)
                || a.app.name.localeCompare(b.app.name))
            let out = []
            for (let i = 0; i < scored.length; i++) out.push(scored[i].app)
            return out
        }
        const byUse = (a, b) => root.usageCount(b.entry.id) - root.usageCount(a.entry.id)
            || a.name.localeCompare(b.name)
        let starts = [], contains = [], comment = []
        for (let i = 0; i < appsCache.length; i++) {
            const a = appsCache[i]
            const n = a.name.toLowerCase()
            if (n.startsWith(q)) starts.push(a)
            else if (n.includes(q)) contains.push(a)
            else if (a.comment.toLowerCase().includes(q)) comment.push(a)
        }
        starts.sort(byUse)
        contains.sort(byUse)
        comment.sort(byUse)
        return starts.concat(contains, comment)
    }

    onResultsChanged: selectedIndex = 0
    // a Tab expansion only belongs to the mode it was opened in
    onModeChanged: descShown = false

    // keep the selection visible when moved by keyboard / on reset
    onSelectedIndexChanged: if (keyboardNav) appList.positionViewAtIndex(selectedIndex, ListView.Contain)
    property bool keyboardNav: false

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            if (root.appsCache.length === 0 || root.shown) loadApps()
        }
    }

    onShownChanged: {
        if (shown) {
            loadApps()
            searchQuery = ""
            searchInput.text = ""
            selectedIndex = 0
            descShown = false
            // forget the previous ">" run so a fresh open never shows stale output
            shellCmd = ""
            shellOut = ""
            shellErr = ""
            shellExit = null
            appList.positionViewAtBeginning()
            searchInput.forceActiveFocus()
        }
    }

    Component.onCompleted: {
        loadApps()
        usageDirProc.running = true
    }

    function loadApps() {
        let entries = DesktopEntries.applications ? DesktopEntries.applications.values : []
        let list = []
        for (let i = 0; i < entries.length; i++) {
            let e = entries[i]
            list.push({
                name: e.name,
                comment: e.comment || "",
                icon: e.icon,
                entry: e
            })
        }
        list.sort((a, b) => a.name.localeCompare(b.name))
        appsCache = list
    }

    function launchSelected() {
        // finished command on screen: Enter re-runs it
        if (shellShown) {
            if (!shellBusy) runShell(shellCmd)
            return
        }
        if (mode !== "apps") {
            runAction(actionRow)
            return
        }
        if (filteredApps.length === 0) return
        const app = filteredApps[selectedIndex]
        root.recordUsage(app.entry.id)
        const entry = app.entry
        if (entry.runInTerminal) {
            if (!Config.defaultTerminal || Config.defaultTerminal.length === 0) {
                console.log("No defaultTerminal configured, cannot launch this terminal app:", entry.name)
                return
            }
            Quickshell.execDetached([Config.defaultTerminal, "-e", "sh", "-c", entry.command.join(" ")])
        } else {
            entry.execute()
        }
        root.closeRequested()
    }

    // one match per app, shared by the list and the highlighter; the comment
    // tier keeps .desktop descriptions below every name match
    function matchApp(q, a) {
        const name = Fuzzy.best(q, a.name.toLowerCase())
        if (name) return { tier: 0, score: name.score, positions: name.positions }
        const c = Fuzzy.ordered(q, a.comment.toLowerCase())
        if (c) return { tier: 1, score: Fuzzy.quality(c, a.comment.length), positions: [] }
        return null
    }

    // which characters to bold in a row's name, from that row's own match
    function matchPositions(app) {
        const q = searchQuery.toLowerCase()
        if (q.length === 0 || mode !== "apps") return []
        if (Config.appLauncherFuzzySearch) {
            const m = matchApp(q, app)
            return m ? m.positions : []
        }
        const i = app.name.toLowerCase().indexOf(q)
        if (i < 0) return []
        let pos = []
        for (let k = 0; k < q.length; k++) pos.push(i + k)
        return pos
    }

    Rectangle {
        anchors.fill: parent
        radius: 22
        color: Theme.bgD1
        border.color: Theme.borderBg2
        border.width: 1
    }

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
            width: parent.width

            Text {
                text: "Spotlight"
                color: Theme.fg
                font { family: Theme.fontFamily; pixelSize: 12; weight: 700 }
                Layout.alignment: Qt.AlignLeft
                Layout.leftMargin: 5
            }

            Item { Layout.fillWidth: true }

            Text {
                text: root.results.length === 0
                    ? "0 / 0"
                    : (root.selectedIndex + 1) + " / " + root.results.length
                color: Theme.fg4
                font { family: Theme.fontFamily; pixelSize: 9; weight: 300 }
                Layout.alignment: Qt.AlignRight
                Layout.rightMargin: 6
            }
        }

        Rectangle {
            id: searchBox
            width: parent.width
            height: 29
            radius: 8
            color: Theme.bg3
            border.color: searchInput.activeFocus ? Theme.borderBgFocus : Theme.borderBg
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: 120 } }

            // subtle "breathing" scale on focus
            scale: searchInput.activeFocus ? 1.0 : 0.985
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            TextInput {
                id: searchInput
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 28
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.fg
                font { family: Theme.fontFamily; pixelSize: 10 }
                clip: true
                selectByMouse: true

                onTextChanged: root.searchQuery = text

                Text {
                    text: "search apps, =math, ?web, >cmd"
                    color: Theme.fg2
                    font: searchInput.font
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: searchInput.text.length === 0 ? 1 : 0
                    x: searchInput.text.length === 0 ? 0 : 6
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                    Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                }

                // active mode, right aligned in the box
                Text {
                    visible: root.mode !== "apps"
                    text: root.mode
                    color: Theme.accent
                    font { family: Theme.fontFamily; pixelSize: 9; weight: 700 }
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                }

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Down) {
                        root.keyboardNav = true
                        if (root.results.length > 0)
                            root.selectedIndex = (root.selectedIndex + 1) % root.results.length
                        event.accepted = true
                    } else if (event.key === Qt.Key_Up) {
                        root.keyboardNav = true
                        if (root.results.length > 0)
                            root.selectedIndex = root.selectedIndex <= 0
                                ? root.results.length - 1
                                : root.selectedIndex - 1
                        event.accepted = true
                    } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                        // apps: long description, web: the full search url
                        if (root.mode === "apps" || root.mode === "web") root.descShown = !root.descShown
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.launchSelected()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Escape) {
                        // first Esc drops back from finished output to the command
                        if (root.shellShown && !root.shellBusy) root.shellCmd = ""
                        else root.closeRequested()
                        event.accepted = true
                    }
                }
            } 
        }

        ListView {
            id: appList
            width: parent.width
            height: root.viewHeight
            clip: true
            visible: !root.shellShown
            model: root.results
            currentIndex: root.selectedIndex
            highlightFollowsCurrentItem: false
            spacing: root.rowSpacing
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                implicitWidth: 3
                background: Item {}
                contentItem: Rectangle {
                    implicitWidth: 3
                    radius: 2
                    color: Theme.fg4
                    opacity: parent.active ? 0.7 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }
            }

            // sliding selection pill with a slight overshoot
            highlight: Rectangle {
                x: 2
                y: appList.currentItem ? appList.currentItem.y : -999
                width: appList.width - 4
                height: appList.currentItem ? appList.currentItem.height : root.rowHeight
                radius: 12
                color: Theme.bgD
                // height tracks currentItem.height, already animated by the row
                Behavior on y {
                    NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
                }
            }

            delegate: Rectangle {
                id: rowDelegate
                width: appList.width

                readonly property bool selected: index === root.selectedIndex
                // Tab wraps the description (or web url) over several lines inside this row
                readonly property bool expanded: root.descShown && selected
                    && modelData.comment.length > 0
                    && (root.mode === "apps" || root.mode === "web")
                readonly property int wrapExtra: expanded ? Math.max(0, rowComment.implicitHeight - commentMetrics.height) : 0

                // 6px of padding, but only once it really took more lines
                height: root.rowHeight + rowDelegate.wrapExtra + (rowDelegate.wrapExtra > 0 ? 6 : 0)
                Behavior on height { NumberAnimation { duration: root.openDuration; easing.type: Easing.OutCubic } }

                // fade the wrapped text in on the box's own curve as it opens
                property real descFade: 1
                onExpandedChanged: if (expanded) { descFadeAnim.from = 0.25; descFadeAnim.restart() }
                NumberAnimation {
                    id: descFadeAnim
                    target: rowDelegate
                    property: "descFade"
                    to: 1
                    duration: root.openDuration
                    easing.type: Easing.OutCubic
                }

                radius: 9
                color: "transparent"

                readonly property var iconSrc: Quickshell.iconPath(modelData.icon || "", true)

                // staggered reveal: fade + slide up, capped so long lists don't lag
                property real reveal: 0
                opacity: reveal
                transform: Translate { y: (1 - rowDelegate.reveal) * 8 }

                SequentialAnimation {
                    id: revealAnim
                    PauseAnimation { duration: Math.min(index, 9) * 22 }
                    NumberAnimation {
                        target: rowDelegate; property: "reveal"
                        from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic
                    }
                }
                Component.onCompleted: revealAnim.start()

                Connections {
                    target: root
                    function onShownChanged() {
                        if (root.shown) {
                            rowDelegate.reveal = 0
                            revealAnim.restart()
                        }
                    }
                }

                // press feedback
                scale: rowHover.pressed ? 0.98 : 1
                Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }

                // one line of text, the baseline the wrapped height grows from
                FontMetrics { id: commentMetrics; font: rowComment.font }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 10
                    spacing: 10

                    IconImage {
                        id: appIcon
                        visible: !!rowDelegate.iconSrc
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        Layout.alignment: Qt.AlignVCenter
                        source: rowDelegate.iconSrc
                        asynchronous: false
                        scale: rowDelegate.selected ? 1.10 : 1
                        rotation: rowDelegate.selected ? -4 : 0
                        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
                        Behavior on rotation { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                    }

                    // fallback glyph in a soft circle when the icon is missing
                    Rectangle {
                        visible: !rowDelegate.iconSrc
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        Layout.alignment: Qt.AlignVCenter
                        radius: 13
                        color: Theme.bg4
                        Text {
                            anchors.centerIn: parent
                            text: modelData.glyph
                                ? modelData.glyph
                                : (modelData.name.length > 0 ? modelData.name[0].toUpperCase() : "?")
                            color: Theme.fg
                            font { family: Theme.fontFamily; pixelSize: 12; weight: 700 }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: Fuzzy.highlight(modelData.name, root.matchPositions(modelData))
                            textFormat: Text.StyledText
                            color: Theme.fg
                            font { family: Theme.fontFamily; pixelSize: 11; weight: rowDelegate.selected ? 600 : 500 }
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            // nudge selected text right a touch
                            Layout.leftMargin: rowDelegate.selected ? 2 : 0
                            Behavior on Layout.leftMargin { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        }
                        Text {
                            id: rowComment
                            text: modelData.comment
                            visible: text.length > 0
                            color: rowDelegate.expanded ? Theme.fg3 : Theme.fg4
                            font { family: Theme.fontFamily; pixelSize: 9; weight: 500 }
                            opacity: rowDelegate.descFade
                            wrapMode: rowDelegate.expanded ? Text.WordWrap : Text.NoWrap
                            maximumLineCount: 4 // cap, chatty .desktop comments get elided
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            Layout.leftMargin: rowDelegate.selected ? 2 : 0
                            Behavior on color { ColorAnimation { duration: 180 } }
                            Behavior on Layout.leftMargin { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        }
                    }
                }

                MouseArea {
                    id: rowHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: {
                        root.keyboardNav = false
                        root.selectedIndex = index
                    }
                    onClicked: {
                        root.selectedIndex = index
                        root.launchSelected()
                    }
                }
            }

            // empty state
            Text {
                anchors.centerIn: parent
                text: "No apps found"
                color: Theme.fg3
                font { family: Theme.fontFamily; pixelSize: 10 }
                opacity: root.results.length === 0 ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 180 } }
            }
        }

        // ">" command output: hides the list above and takes its place
        ColumnLayout {
            id: outputPanel
            visible: root.shellShown
            width: parent.width
            height: root.viewHeight
            spacing: 6

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 9
                color: Theme.bgD
                border.color: Theme.borderBg2
                border.width: 1

                Flickable {
                    id: outputFlick
                    anchors.fill: parent
                    anchors.margins: 9
                    contentWidth: width
                    contentHeight: outputText.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height

                    Text {
                        id: outputText
                        width: outputFlick.width
                        text: root.shellText.length > 0 ? root.shellText
                            : (root.shellBusy ? "running…" : "(no output)")
                        color: Theme.fg2
                        font { family: Theme.nerdFontFamily; pixelSize: 10 }
                        wrapMode: Text.WrapAnywhere
                    }

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        implicitWidth: 3
                        background: Item {}
                        contentItem: Rectangle {
                            implicitWidth: 3
                            radius: 2
                            color: Theme.fg4
                            opacity: parent.active ? 0.7 : 0
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                        }
                    }
                }
            }

            Text {
                Layout.leftMargin: 7
                text: root.shellBusy ? "running.."
                    : (root.shellExit === 0 ? " exit 0" : "✕ exit " + root.shellExit)
                color: root.shellBusy ? Theme.fg4
                    : (root.shellExit === 0 ? "#46e03b" : Theme.deleting)
                font { family: Theme.fontFamily; pixelSize: 9; weight: 500 }
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
