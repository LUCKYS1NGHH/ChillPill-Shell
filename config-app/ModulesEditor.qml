import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import "components"
import "."

ColumnLayout {
    id: m
    property var value: []
    property var known: []
    signal edited(var v)
    Layout.fillWidth: true
    spacing: 8

    property bool editingModule: false
    property int customIndex: -1

    readonly property var customCache: ConfigStore.customCache
    readonly property var builtinAvail: known.filter(k => value.indexOf(k) < 0)
    readonly property var cachedAvail: m.customCache.filter(
        e => !value.some(o => typeof o === "object" && String(o.run) === String(e.run)))
    readonly property var available: builtinAvail.concat(cachedAvail)
    // live tray icons not already placed in the bar
    readonly property var trayAvail: SystemTray.items.values
        .filter(i => !value.some(o => typeof o === "object" && o !== null && o.tray === i.id))
        .map(i => ({ tray: i.id }))

    function syncCache() {
        if (!ConfigStore.customCacheLoaded) return
        var c = m.customCache.slice()
        for (var i = 0; i < m.value.length; i++) {
            var e = m.value[i]
            if (typeof e !== "object" || e === null) continue
            // tray entries ({tray: id}) are system state, not user modules
            if (e.tray !== undefined) continue
            var run = String(e.run)
            var idx = -1
            for (var j = 0; j < c.length; j++)
                if (String(c[j].run) === run) { idx = j; break }
            if (idx < 0) c.push(e)
            else if (JSON.stringify(c[idx]) !== JSON.stringify(e)) c[idx] = e
        }
        ConfigStore.setCustomCache(c)
    }

    function removeFromCache(entry) {
        ConfigStore.setCustomCache(
            m.customCache.filter(e => String(e.run) !== String(entry.run)))
    }
    onValueChanged: m.syncCache()
    Component.onCompleted: m.syncCache()

    Connections {
        target: ConfigStore
        function onCustomCacheChanged() { m.syncCache() }
        function onCustomCacheLoadedChanged() { m.syncCache() }
    }

    function openNewCustom() {
        m.customIndex = -1
        customForm.entry = null
        customForm.open()
        m.editingModule = true
    }
    function openEditCustom(i) {
        m.customIndex = i
        customForm.entry = m.value[i]
        customForm.open()
        m.editingModule = true
    }
    function saveCustom(entry) {
        var a = m.value.slice()
        if (m.customIndex >= 0) a[m.customIndex] = entry
        else a.push(entry)
        m.editingModule = false
        m.edited(a)
    }

    Text {
        visible: m.value.length > 0
        text: "Drag to Reorder · Drag a module onto the list below to remove"
        color: Theme.fg4
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }
    PillBarPreview {
        id: bar
        known: m.known
        value: m.value
        removeArea: leftoverArea
        onEdited: (v) => m.edited(v)
        onEditRequested: (slot) => m.openEditCustom(slot)
    }

    Text {
        Layout.fillWidth: true
        visible: m.value.length === 0
        text: "The pill bar is empty, drag a module below onto it"
        color: Theme.fg6
        font.family: Theme.fontFamily
    }

    Text {
        text: "ADD MODULES"
        color: Theme.fg4
        font.family: Theme.fontFamily
        font.pixelSize: 10
    }
    Item {
        id: leftoverArea
        Layout.fillWidth: true
        implicitHeight: leftoverFlow.implicitHeight

        Rectangle {
            id: dropZone
            anchors.fill: parent
            radius: 12
            z: 2
            visible: opacity > 0.01
            opacity: bar.dragActive ? 1 : 0
            color: bar.removeTarget ? Theme.deleteOverlayFaint : Theme.dragOverlayFaint
            border.color: bar.removeTarget ? Theme.deleteOverlayBorderFaint : Theme.dragOverlayBorderFaint
            border.width: 1
            Behavior on opacity { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 130 } }
            Behavior on border.color { ColorAnimation { duration: 130 } }

            Rectangle {
                id: dropBadge
                anchors.centerIn: parent
                width: dropRow.implicitWidth + 26
                height: 28
                radius: 14
                color: bar.removeTarget ? Theme.deleteOverlay : Theme.dragOverlay
                border.color: bar.removeTarget ? Theme.deleteOverlayBorder : Theme.dragOverlayBorder
                border.width: 1
                scale: bar.removeTarget ? 1 : 0.92
                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                Behavior on color { ColorAnimation { duration: 130 } }
                Behavior on border.color { ColorAnimation { duration: 130 } }

                Row {
                    id: dropRow
                    anchors.centerIn: parent
                    spacing: 7
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: String.fromCodePoint(0xef90)
                        color: bar.removeTarget ? Theme.deleting : Theme.fg4
                        font.family: Theme.nerdFontFamily
                        font.pixelSize: 11
                        Behavior on color { ColorAnimation { duration: 130 } }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "release to remove"
                        color: bar.removeTarget ? Theme.deleting : Theme.fg4
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 0.3
                        Behavior on color { ColorAnimation { duration: 130 } }
                    }
                }
            }
        }

        Flow {
            id: leftoverFlow
            width: parent.width
            spacing: 12
            Repeater {
                model: m.available
                ModuleThumb {
                    id: addThumb
                    required property var modelData
                    readonly property bool isCustom: typeof modelData === "object"
                    height: 30
                    readonly property var props: bar.thumbProps(modelData)
                    icon: props.icon
                    text: props.text
                    iconColor: props.color
                    segments: props.segments === true
                    spectrum: props.spectrum === true
                    segmentCount: props.segN || 0
                    activeSegment: props.activeSeg !== undefined ? props.activeSeg : -1
                    flag: props.flag === true
                    flagColor: props.flagColor
                    iconSize: props.iconSize || 10
                    removable: addThumb.isCustom
                    onRemoveRequested: m.removeFromCache(modelData)
                    onDragBegin: (lx, gx, gy) => bar.availBegin(modelData, lx, gx, gy)
                    onDragMove: (gx, gy) => bar.availMove(gx, gy)
                    onDragEnd: bar.availEnd
                }
            }
        }
    }

    // second row: available tray modules, same drag-onto-the-bar behaviour
    ColumnLayout {
        visible: m.trayAvail.length > 0
        Layout.fillWidth: true
        spacing: 8

        Text {
            text: "TRAY MODULES"
            color: Theme.fg4
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }
        Row {
            spacing: 12
            Repeater {
                model: m.trayAvail
                ModuleThumb {
                    required property var modelData
                    height: 30
                    readonly property var props: bar.thumbProps(modelData)
                    icon: props.icon
                    imageIcon: props.imageIcon || ""
                    text: props.text
                    iconColor: props.color
                    flag: props.flag === true
                    flagColor: props.flagColor
                    iconSize: props.iconSize || 13
                    onDragBegin: (lx, gx, gy) => bar.availBegin(modelData, lx, gx, gy)
                    onDragMove: (gx, gy) => bar.availMove(gx, gy)
                    onDragEnd: bar.availEnd
                }
            }
        }
    }

    Rectangle {
        id: customAdd
        Layout.alignment: Qt.AlignLeft
        implicitWidth: customAddLbl.implicitWidth + 26
        height: 30; radius: 15
        color: customAddMa.containsMouse ? Theme.accent : Theme.transparent
        border.color: Theme.accent
        Text {
            id: customAddLbl
            anchors.centerIn: parent
            text: "+ Custom module"
            color: customAddMa.containsMouse ? Theme.bgD : Theme.accent
            font.family: Theme.fontFamily
        }
        MouseArea {
            id: customAddMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: m.openNewCustom()
        }
    }

    Text {
        Layout.fillWidth: true
        visible: m.value.length > 0 && m.available.length === 0
        text: "Every built-in module is in the bar"
        color: Theme.fg6
        font.family: Theme.fontFamily
    }

    CustomModuleForm {
        id: customForm
        Layout.fillWidth: true
        Layout.topMargin: 4
        visible: m.editingModule
        onAccepted: (entry) => m.saveCustom(entry)
        onRejected: m.editingModule = false
    }
}