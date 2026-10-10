import Quickshell
import Quickshell.Widgets
import QtQuick
import Quickshell.Services.Mpris

Rectangle {
    id: mediaCard
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: mprisModule.hasPlayer ? 118 : 0
    radius: 16
    color: Theme.bgD
    visible: height > 0
    clip: true
    border.color: Theme.borderBg3
    border.width: 1

    // card slides open / closed instead of popping
    Behavior on height { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }

    property int margin: 16

    // artist name adjustments
    property int artistFontSize: 10
    property string artistFontColor: Theme.fg4
    property int artistFontWeight: 300

    property real mprisProgress: 0
    property string mprisTimePlayed: "0:00"
    property string mprisTimeTotal: "0:00"

    // seek state
    property bool seeking: false
    property real seekRatio: 0
    readonly property real shownProgress: seeking ? seekRatio : mprisProgress
    readonly property real totalSeconds: Number(mprisModule.polledLength) || 0

    function formatMprisTime(val) {
        let n = Number(val)
        if (isNaN(n) || n <= 0) return "0:00"
        let m = Math.floor(n / 60)
        let s = Math.floor(n % 60)
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    function seekTo(ratio) {
        let p = mprisModule.activePlayer
        if (!p) return
        ratio = Math.max(0, Math.min(1, ratio))
        let len = Number(p.length) || 0
        if (len <= 0 && p.metadata && p.metadata["mpris:length"])
            len = Number(p.metadata["mpris:length"])
        if (len > 0) p.position = ratio * len
    }

    // Two-buffer image: new cover loads in the background and only
    // fades in once ready, while the old one fades out -> crossfade,
    component CrossfadeImage: Item {
        id: cf
        property url source
        property size sourceSize: Qt.size(0, 0)
        property real maxOpacity: 1
        property int fadeDuration: 420
        property int current: 0          // 0 = nothing, 1 = A, 2 = B

        function stage(target, which) {
            if (target.source.toString() === cf.source.toString() && target.status === Image.Ready)
                cf.current = which
            else
                target.source = cf.source
        }

        onSourceChanged: {
            if (cf.source.toString() === "") { cf.current = 0; return }
            if (cf.current === 1) stage(imgB, 2)
            else stage(imgA, 1)
        }
        Component.onCompleted: {
            if (cf.source.toString() !== "" && cf.current === 0) stage(imgA, 1)
        }

        Image {
            id: imgA
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            cache: false
            asynchronous: true
            sourceSize: cf.sourceSize
            visible: opacity > 0
            opacity: cf.current === 1 ? cf.maxOpacity : 0
            scale: cf.current === 1 ? 1 : 1.05
            Behavior on opacity { NumberAnimation { duration: cf.fadeDuration; easing.type: Easing.InOutQuad } }
            Behavior on scale { NumberAnimation { duration: cf.fadeDuration + 250; easing.type: Easing.OutCubic } }
            onStatusChanged: {
                if (source.toString() !== cf.source.toString()) return
                if (status === Image.Ready) cf.current = 1
                else if (status === Image.Error) cf.current = 0
            }
        }

        Image {
            id: imgB
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            cache: false
            asynchronous: true
            sourceSize: cf.sourceSize
            visible: opacity > 0
            opacity: cf.current === 2 ? cf.maxOpacity : 0
            scale: cf.current === 2 ? 1 : 1.05
            Behavior on opacity { NumberAnimation { duration: cf.fadeDuration; easing.type: Easing.InOutQuad } }
            Behavior on scale { NumberAnimation { duration: cf.fadeDuration + 250; easing.type: Easing.OutCubic } }
            onStatusChanged: {
                if (source.toString() !== cf.source.toString()) return
                if (status === Image.Ready) cf.current = 2
                else if (status === Image.Error) cf.current = 0
            }
        }
    }

    // - round hover/press pill that blooms in
    // - glyph swells on hover, squashes on press, springs back
    // - prev/next glyph nudges in its direction on click
    // - optional alt glyph (play <-> pause) crossfades with a spin
    component ControlButton: Item {
        id: btn
        property string glyph: ""
        property string altGlyph: ""
        property bool showAlt: false
        property color idleColor: Theme.fg3
        property color hoverColor: "white"
        property real glyphSize: 23
        property real nudge: 0
        property bool primary: false
        signal clicked()

        width: 32
        height: 32

        readonly property bool hovered: ma.containsMouse
        readonly property bool pressed: ma.pressed
        readonly property color tint: hovered ? hoverColor : idleColor
        property real nudgeX: 0

        SequentialAnimation {
            id: nudgeAnim
            NumberAnimation { target: btn; property: "nudgeX"; to: btn.nudge; duration: 90; easing.type: Easing.OutQuad }
            NumberAnimation { target: btn; property: "nudgeX"; to: 0; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
        }

        // hover / press pill
        Rectangle {
            anchors.centerIn: parent
            width: 30; height: 30; radius: 16
            color: Theme.fgL
            opacity: btn.pressed ? 0.16 : (btn.hovered ? 0.10 : (btn.primary ? 0.05 : 0))
            scale: btn.pressed ? 0.92 : ((btn.hovered || btn.primary) ? 1.0 : 0.7)
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
        }

        // glyph holder
        Item {
            width: 30; height: 30
            x: (btn.width - width) / 2 + btn.nudgeX
            y: (btn.height - height) / 2
            scale: btn.pressed ? 0.84 : (btn.hovered ? 1.1 : 1.0)
            Behavior on scale {
                NumberAnimation {
                    duration: btn.pressed ? 80 : 320
                    easing.type: btn.pressed ? Easing.OutQuad : Easing.OutBack
                    easing.overshoot: 2.0
                }
            }

            Text {
                anchors.centerIn: parent
                text: btn.glyph
                font.family: Theme.nerdFontFamily
                font.pixelSize: btn.glyphSize
                color: btn.tint
                opacity: btn.showAlt ? 0 : 1
                scale: btn.showAlt ? 0.4 : 1
                rotation: btn.showAlt ? -90 : 0
                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
                Behavior on rotation { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
            }

            Text {
                anchors.centerIn: parent
                visible: btn.altGlyph !== ""
                text: btn.altGlyph
                font.family: Theme.nerdFontFamily
                font.pixelSize: btn.glyphSize
                color: btn.tint
                opacity: btn.showAlt ? 1 : 0
                scale: btn.showAlt ? 1 : 0.4
                rotation: btn.showAlt ? 0 : 90
                Behavior on color { ColorAnimation { duration: 160 } }
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
                Behavior on rotation { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (btn.nudge !== 0) nudgeAnim.restart()
                btn.clicked()
            }
        }
    }

    // poll every second
    Timer {
        id: progressPoller
        interval: 1000
        running: box.controlCenter && mprisModule.hasPlayer
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (mediaCard.seeking) return
            mediaCard.mprisProgress = mprisModule.progress
            mediaCard.mprisTimePlayed = mediaCard.formatMprisTime(mprisModule.polledPosition)
            mediaCard.mprisTimeTotal = mediaCard.formatMprisTime(mprisModule.polledLength)
        }
    }

    // fixed-size wrapper so the open/close animation reveals the content instead of squashing it
    Item {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 118
        opacity: Math.min(1, mediaCard.height / 118)

        // cover-art wash, fading out to the right (Config.iWantMediaCoverInBackground toggle)
        ClippingRectangle {
            anchors.fill: parent
            anchors.margins: mediaCard.border.width
            radius: mediaCard.radius - mediaCard.border.width
            color: "transparent"

            CrossfadeImage {
                anchors.fill: parent
                source: Config.iWantMediaCoverInBackground ? mprisModule.artUrl : ""
                sourceSize: Qt.size(128, 128)
                maxOpacity: 0.12
                fadeDuration: 350
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.8; color: Theme.bgD }
                }
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 15

            // top row -> art + info + controls
            Row {
                width: parent.width
                height: 48
                spacing: 15

                // album art
                ClippingRectangle {
                    id: artBox
                    width: 47; height: 47
                    radius: 7
                    color: "transparent"
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true

                    CrossfadeImage {
                        anchors.fill: parent
                        source: mprisModule.artUrl
                        sourceSize: Qt.size(94 * box.dpi, 94 * box.dpi)
                        fadeDuration: 380
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf001"
                        font.family: Theme.nerdFontFamily
                        font.pixelSize: 18
                        color: Theme.fg4
                        opacity: mprisModule.artUrl === "" ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    }
                }

                // track + artist
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, parent.width - artBox.width - controls.width - parent.spacing * 2)
                    spacing: 4

                    // title: marquee when Config.marqueeMediaText, else elided text
                    Item {
                        id: titleHolder
                        width: parent.width
                        height: 15

                        Text {
                            id: titleText
                            anchors.fill: parent
                            text: mprisModule.track !== "" ? mprisModule.track : "Nothing playing"
                            color: Theme.fgL
                            font.pixelSize: 12
                            font.weight: 600
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                            visible: !Config.marqueeMediaText
                            onTextChanged: titleSwap.restart()
                        }

                        MarqueeText {
                            id: titleMarquee
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Config.marqueeMediaText
                            maxWidth: width
                            text: mprisModule.track !== "" ? mprisModule.track : "Nothing playing"
                            color: Theme.fgL
                            font.pixelSize: 12
                            font.weight: 600
                            font.family: Theme.fontFamily
                            onTextChanged: titleSwap.restart()
                        }

                        SequentialAnimation {
                            id: titleSwap
                            PropertyAction { target: titleHolder; property: "opacity"; value: 0 }
                            PropertyAction { target: titleHolder; property: "x"; value: 10 }
                            ParallelAnimation {
                                NumberAnimation { target: titleHolder; property: "opacity"; to: 1; duration: 340; easing.type: Easing.OutCubic }
                                NumberAnimation { target: titleHolder; property: "x"; to: 0; duration: 420; easing.type: Easing.OutQuint }
                            }
                        }
                    }

                    // artist
                    Item {
                        id: artistHolder
                        width: parent.width
                        height: 13

                        Text {
                            id: artistText
                            anchors.fill: parent
                            text: mprisModule.artist
                            color: artistFontColor
                            font.pixelSize: artistFontSize
                            font.weight: artistFontWeight
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                            visible: !Config.marqueeMediaText
                            onTextChanged: artistSwap.restart()
                        }

                        MarqueeText {
                            id: artistMarquee
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Config.marqueeMediaText
                            maxWidth: width
                            text: mprisModule.artist
                            color: mediaCard.artistFontColor
                            font.pixelSize: mediaCard.artistFontSize
                            font.weight: mediaCard.artistFontWeight
                            font.family: Theme.fontFamily
                            onTextChanged: artistSwap.restart()
                        }

                        // staggered slightly behind the title
                        SequentialAnimation {
                            id: artistSwap
                            PropertyAction { target: artistHolder; property: "opacity"; value: 0 }
                            PropertyAction { target: artistHolder; property: "x"; value: 10 }
                            PauseAnimation { duration: 70 }
                            ParallelAnimation {
                                NumberAnimation { target: artistHolder; property: "opacity"; to: 1; duration: 340; easing.type: Easing.OutCubic }
                                NumberAnimation { target: artistHolder; property: "x"; to: 0; duration: 420; easing.type: Easing.OutQuint }
                            }
                        }
                    }
                }

                // controls
                Row {
                    id: controls
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    ControlButton {
                        glyph: "\u23ee"                     // ⏮
                        idleColor: Theme.fg3
                        nudge: -5
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: mprisModule.prev()
                    }

                    ControlButton {
                        glyph: "\udb80\udfe4"               // 󰏤 pause
                        altGlyph: "\udb81\udc0a"            // 󰐊 play
                        showAlt: !mprisModule.playing
                        idleColor: Theme.fg2
                        glyphSize: 18
                        primary: true
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: mprisModule.playPause()
                    }

                    ControlButton {
                        glyph: "\u23ed"                     // ⏭
                        idleColor: Theme.fg3
                        nudge: 5
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: mprisModule.next()
                    }
                }
            }

            // progress bar + time
            Column {
                width: parent.width
                spacing: 8

                // layout slot stays 3px tall; visuals and hit area overflow it
                Item {
                    id: barSlot
                    width: parent.width
                    height: 3

                    readonly property bool active: seekMouse.containsMouse || mediaCard.seeking

                    Rectangle {
                        id: track
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: barSlot.active ? 6 : 3
                        radius: height / 2
                        color: Theme.bg5
                        Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutExpo } }

                        // ghost preview up to the hover point
                        Rectangle {
                            width: track.width * seekMouse.hoverRatio
                            height: parent.height
                            radius: parent.radius
                            color: Theme.fg3
                            opacity: barSlot.active ? 0.35 : 0
                            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        }

                        // real progress
                        Rectangle {
                            id: fill
                            width: track.width * mediaCard.shownProgress
                            height: parent.height
                            radius: parent.radius
                            color: barSlot.active ? Theme.fg2 : Theme.fgL
                            Behavior on color { ColorAnimation { duration: 200 } }
                            Behavior on width {
                                enabled: !mediaCard.seeking
                                NumberAnimation { duration: 1000; easing.type: Easing.Linear }
                            }
                        }

                        // scrub knob: pops in on hover, a bit bigger while dragging
                        Rectangle {
                            width: 12; height: 12; radius: 6
                            color: Theme.fgL
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(track.width - width, fill.width - width / 2))
                            scale: !barSlot.active ? 0 : (mediaCard.seeking ? 1.25 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }
                        }
                    }

                    // generous hit area around the slim bar
                    MouseArea {
                        id: seekMouse
                        anchors.fill: parent
                        anchors.topMargin: -7
                        anchors.bottomMargin: -7
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        property real hoverRatio: 0

                        onPositionChanged: (mouse) => {
                            hoverRatio = Math.max(0, Math.min(1, mouse.x / width))
                            if (pressed) mediaCard.seekRatio = hoverRatio
                        }
                        onPressed: (mouse) => {
                            hoverRatio = Math.max(0, Math.min(1, mouse.x / width))
                            mediaCard.seekRatio = hoverRatio
                            mediaCard.seeking = true
                        }
                        onReleased: {
                            mediaCard.seekTo(mediaCard.seekRatio)
                            mediaCard.mprisProgress = mediaCard.seekRatio
                            mediaCard.seeking = false
                        }
                        onCanceled: mediaCard.seeking = false
                    }
                }

                Item {
                    width: parent.width
                    height: 12

                    Text {
                        anchors.left: parent.left
                        // while hovering/dragging, show where a click would land
                        text: barSlot.active
                              ? mediaCard.formatMprisTime(seekMouse.hoverRatio * mediaCard.totalSeconds)
                              : mediaCard.mprisTimePlayed
                        color: barSlot.active ? Theme.fgL : Theme.fg5
                        font.pixelSize: 10
                        font.family: Theme.fontFamily
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }

                    Text {
                        anchors.right: parent.right
                        text: mediaCard.mprisTimeTotal
                        color: barSlot.active ? Theme.fg3 : Theme.fg5
                        font.pixelSize: 10
                        font.family: Theme.fontFamily
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }
                }
            }
        }
    }

    AudioVisualizer {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        values: shellRoot.visualizerValues ? shellRoot.visualizerValues.slice(1, barCount) : []
        visible: Config.showAudioVisuals && shellRoot.cavaAvailable && mprisModule.hasPlayer
    }
}
