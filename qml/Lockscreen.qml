pragma ComponentBehavior: Bound

// Lives next to shell.qml so it picks up Config.qml / Theme.qml directly.
// Config:   ~/.config/chillpill-shell/config.jsonc via Config.qml (displayPicture, clockFormat,
//           textFontFamily, nerdFontFamily, pillModules, dpiScale, showShadows, confirmPowerActions,
//           lockscreenPowerActions, lockscreenMedia, weatherLocation, weatherUnits, weatherRefreshInterval)
// As your lock command (screenLockAppCommand): env LOCK_NOW=1 qs -p /path/to/lockscreen.qml
// Wallpaper: $LOCK_WALLPAPER when set, else the path stored in
//           ~/.cache/chillpill-shell/last_wallpaper
// Colors:   everything comes from qml/Theme.qml

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Pam
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Scope {
    id: root

    // environment
    readonly property string envWallpaper: Quickshell.env("LOCK_WALLPAPER") || ""
    readonly property string userName: Quickshell.env("USER") || "user"
    readonly property string home: Quickshell.env("HOME") || ""
    readonly property bool oneshot: Quickshell.env("LOCK_NOW") === "1"
    readonly property string pamConfig: "login"

    function expandHome(p) {
        return (p && p.startsWith("~")) ? home + p.slice(1) : p;
    }

    readonly property string textFont: Theme.fontFamily
    readonly property string nerdFont: Theme.nerdFontFamily
    readonly property string clockFmt: "hh:mm AP"
    readonly property real pillW: 440
    readonly property real pillH: Math.round(44 * Config.pillScale) + 10
    readonly property real pillR: 20 * Config.pillScale
    readonly property real pillCenterY: Config.pillTopMargin + pillH / 2
    readonly property string avatarPath: expandHome(Config.displayPicture)
    readonly property real dpiScale: Config.dpiScale
    readonly property bool confirmPower: Config.confirmPowerActions
    readonly property bool showBattery: Config.pillModules.indexOf("battery") !== -1

    // mirrored from the media card so the type scale can react to it
    property bool mediaActive: false
    readonly property bool mediaShown: Config.lockscreenMedia && mediaActive

    // weather (same endpoint + glyphs as qml/WeatherModule.qml)
    readonly property string wLocation: Config.weatherLocation
    readonly property string wUnits: Config.weatherUnits
    readonly property bool wMetric: wUnits !== "imperial"

    property bool wLoading: true
    property real wTemp: NaN
    property string wUnit: "°C"
    property string wGlyph: "\ue312"
    property string wGlyphColor: Theme.weatherCloudy
    readonly property bool wOk: wLocation !== "" && !isNaN(wTemp)

    function wIconForCode(code) {
        const c = parseInt(code);
        if (c === 113)
            return { glyph: "\ue30d", color: Theme.weatherClear };
        if ([116, 119, 122].indexOf(c) !== -1)
            return { glyph: "\ue312", color: Theme.weatherCloudy };
        if ([176, 263, 266, 293, 296, 299, 302, 305, 308, 311, 314, 317, 320, 353, 356, 359].indexOf(c) !== -1)
            return { glyph: "\ue318", color: Theme.weatherRain };
        if ([200, 386, 389, 392, 395].indexOf(c) !== -1)
            return { glyph: "\ue31d", color: Theme.weatherThunder };
        if ([227, 230, 323, 326, 329, 332, 335, 338, 350, 368, 371, 374, 377].indexOf(c) !== -1)
            return { glyph: "\ue31a", color: Theme.weatherSnow };
        if ([143, 248, 260].indexOf(c) !== -1)
            return { glyph: "\ue313", color: Theme.weatherFog };
        return { glyph: "\ue312", color: Theme.weatherCloudy };
    }

    function refreshWeather() {
        if (root.wLocation === "")
            return;
        root.wLoading = true;
        const metric = root.wMetric;
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            root.wLoading = false;
            if (xhr.status !== 200)
                return;
            try {
                const d = JSON.parse(xhr.responseText);
                const cur = d.current_condition[0];
                root.wTemp = parseFloat(metric ? cur.temp_C : cur.temp_F);
                root.wUnit = metric ? "°C" : "°F";
                const ic = root.wIconForCode(cur.weatherCode);
                root.wGlyph = ic.glyph;
                root.wGlyphColor = ic.color;
            } catch (e) {
            }
        };
        xhr.open("GET", "https://wttr.in/" + encodeURIComponent(root.wLocation) + "?format=j1");
        xhr.send();
    }

    // timer for the weather refresh
    Timer {
        id: wxTimer
        interval: Math.max(60000, Config.weatherRefreshInterval)
        repeat: true
        running: sessionLock.locked && root.wLocation !== ""
        triggeredOnStart: true
        onTriggered: root.refreshWeather()
    }

    // ---------- idle dim: drop the backlight after N idle seconds, wake on input ----------
    property int savedBrightness: -1
    property bool dimmed: false
    property bool dimPending: false
    property int lastBright: -1
    readonly property int dimTarget: Math.max(1, Math.round(savedBrightness * Config.lockscreenIdleDimTo / 100))

    Process {
        id: brightGet
        command: ["brightnessctl", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(text.trim());
                if (isNaN(v) || v <= 0) {
                    root.dimPending = false;
                    return;
                }
                root.savedBrightness = v;
                root.lastBright = v;
                if (!root.dimPending)
                    return;
                root.dimPending = false;
                root.dimmed = true;
                startBrightAnim(v, root.dimTarget, dimDuration)
            }
        }
    }

    Process {
        id: brightSet
    }

    // smooth backlight transitions: stepped brightnessctl commands on a timer
    property int dimDuration: 1400
    property int wakeDuration: 500

    Timer {
        id: brightAnim
        interval: 80
        repeat: true
        running: false
        property int fromV: 0
        property int toV: 0
        property int durationMs: 1
        property real progress: 0
        onTriggered: {
            progress = Math.min(1, progress + interval / durationMs);
            const e = progress < 0.5 ? 2 * progress * progress
                : 1 - Math.pow(-2 * progress + 2, 2) / 2;   // easeInOutQuad
            const v = Math.round(fromV + (toV - fromV) * e);
            if (v !== root.lastBright) {
                root.lastBright = v;
                brightSet.command = ["brightnessctl", "set", v];
                brightSet.running = true;
            }
            if (progress >= 1)
                stop();
        }
    }

    function startBrightAnim(fromV, toV, duration) {
        brightAnim.fromV = fromV;
        brightAnim.toV = toV;
        brightAnim.durationMs = duration;
        brightAnim.progress = 0;
        brightAnim.restart();
    }

    function dimScreen() {
        if (Config.lockscreenIdleDim <= 0 || root.dimmed || root.dimPending)
            return;
        root.dimPending = true;
        brightGet.running = true;
    }

    function wakeScreen() {
        root.dimPending = false;
        if (!root.dimmed)
            return;
        root.dimmed = false;
        if (root.savedBrightness > 0)
            startBrightAnim(root.lastBright, root.savedBrightness, wakeDuration)
    }

    function activity() {
        idleDim.restart();
        wakeScreen();
    }

    Timer {
        id: idleDim
        interval: Math.max(1, Config.lockscreenIdleDim) * 1000
        running: sessionLock.locked && Config.lockscreenIdleDim > 0 && !root.unlocking
        onTriggered: root.dimScreen()
    }

    // ---------- shared state (all monitors) ----------
    property string buffer: ""
    property bool reveal: false   // show the password instead of the bullets (ctrl+v)
    property bool checking: false
    property bool failed: false
    property bool unlocking: false
    property int failCount: 0
    property int cooldown: 0
    property bool pamRecord: false      // pam_faillock still has failures on record
    property bool confirmArmed: false  // second enter confirms when it matters
    readonly property bool lockedOut: cooldown > 0
    readonly property bool pamRisky: pamRecord || failCount > 0
    readonly property bool pamLocked: failCount >= 3
    readonly property string statusText: {
        if (unlocking)
            return "welcome back";
        if (pamLocked)
            return "locked by pam \uf444 tap the arrow to reset";
        if (lockedOut)
            return "too many attempts \uf444 wait " + cooldown + "s";
        if (checking)
            return "verifying\u2026";
        if (confirmArmed)
            return "press enter again to submit";
        if (failed)
            return "wrong password \uf444 " + failCount + (failCount === 1 ? " attempt" : " attempts");
        if (pamRisky)
            return "pam counts earlier failures  \u00b7  enter again to submit";
        return "Enter to unlock \uf444 Esc to clear \uf444 Ctrl+V to " + (root.reveal ? "hide" : "peek");
    }
    readonly property string detectedWallpaper: {
        let p = wpFile.text().split("\n")[0].trim();
        if (p.startsWith("file://"))
            p = p.slice(7);
        return expandHome(p);
    }
    readonly property string wallpaper: envWallpaper !== "" ? envWallpaper : detectedWallpaper
    signal shake

    function pad(n) {
        return String(n).padStart(2, "0");
    }

    function greeting() {
        const h = clock.hours;
        const t = h < 5 ? "burning the midnight oil" : h < 12 ? "good morning" : h < 17 ? "good afternoon" : h < 22 ? "good evening" : "late night";
        return t + ", " + userName;
    }

    // same glyph set + colors as the shell
    readonly property var batGlyphs: [0xf0083, 0xf007a, 0xf007d, 0xf007c, 0xf007d, 0xf007e, 0xf007f, 0xf0082, 0xf0081, 0xf0079]

    function batteryGlyph(pct) {
        if (!(pct >= 0))
            return "";
        const base = String.fromCodePoint(root.batGlyphs[Math.min(Math.floor(pct / 10), 9)]);
        return root.batCharging ? base + String.fromCodePoint(0xf140b) : base;
    }

    function batteryColor(pct) {
        return pct > 30 ? Theme.ok : (pct <= 15 ? Theme.danger : Theme.warnMed);
    }

    function onFailure() {
        root.checking = false;
        root.failed = true;
        root.failCount++;
        root.buffer = "";
        root.reveal = false;
        root.confirmArmed = false;
        root.shake();
        // pam_faillock denies=3/unlock_time=900: one miss left means a slow down
        root.cooldown = root.failCount === 1 ? 0 : (root.failCount === 2 ? 5 : 900);
        refreshFailTally();
    }

    function submit() {
        if (checking || unlocking || lockedOut || buffer.length === 0)
            return;
        if (pamLocked) {
            resetPamTally();
            return;
        }
        // once pam has a record, every submit has to be confirmed on purpose
        if (pamRisky && !confirmArmed) {
            confirmArmed = true;
            confirmTimer.restart();
            return;
        }
        confirmArmed = false;
        checking = true;
        failed = false;
        pam.start();
    }

    function refreshFailTally() {
        if (!faillockProc.running)
            faillockProc.running = true;
    }

    function resetPamTally() {
        resetProc.command = ["pkexec", "faillock", "--user", Quickshell.env("USER") || "root", "--reset"];
        resetProc.running = true;
    }

    // ---------- theme ----------
    // neutrals come from the shell's Theme.qml
    QtObject {
        id: th
        readonly property color bg: Theme.bg
        readonly property color fg: Theme.fg
        readonly property color error: Theme.deleting
        readonly property color surface: Theme.bgD1
        readonly property color panel: Theme.bgD
        readonly property color surfaceHi: Theme.bg4
        readonly property color fieldBg: Theme.bg3
        readonly property color stroke: Theme.borderBg2
        readonly property color sub: Theme.fg4
        readonly property color hi: Theme.fg3
    }

    // ---------- plumbing ----------
    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    PamContext {
        id: pam
        config: root.pamConfig

        onPamMessage: {
            if (pam.responseRequired)
                pam.respond(root.buffer);
        }

        onCompleted: result => {
            if (result === PamResult.Success) {
                root.checking = false;
                root.unlocking = true;
                root.failed = false;
                root.cooldown = 0;
                unlockTimer.start();
            } else {
                root.onFailure();
            }
        }

        onError: root.onFailure()
    }

    // never let a silent pam hang wedge the screen in "verifying"
    Timer {
        id: pamWatchdog
        interval: 10000
        running: root.checking
        onTriggered: if (root.checking) root.onFailure()
    }

    Timer {
        id: confirmTimer
        interval: 2500
        onTriggered: root.confirmArmed = false
    }

    // counts the cooldown down once a second and clears the error state after
    Timer {
        id: cooldownTimer
        interval: 1000
        repeat: true
        running: root.cooldown > 0
        onTriggered: {
            root.cooldown = Math.max(0, root.cooldown - 1);
            if (root.cooldown === 0) {
                root.failed = false;
                refreshFailTally();
            }
        }
    }

    // forget old failures once the user stops typing for a while
    Timer {
        id: failReset
        interval: 45000
        onTriggered: {
            root.failCount = 0;
            root.failed = false;
        }
    }

    Timer {
        id: unlockTimer
        interval: 480
        onTriggered: {
            sessionLock.locked = false;
            if (root.oneshot)
                quitTimer.start();
        }
    }

    // give the compositor time to see the unlock before we exit
    Timer {
        id: quitTimer
        interval: 400
        onTriggered: Qt.quit()
    }

    // get the current wallpaper file path from ~/.cache/chillpill-shell
    FileView {
        id: wpFile
        path: root.home + "/.cache/chillpill-shell/last_wallpaper"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }

    Process {
        id: powerProc
    }

    // pam_faillock keeps its tally for fail_interval seconds, across relocks and
    // across shells, so the ui has to ask it instead of counting on its own
    Process {
        id: faillockProc
        command: ["faillock", "--user", Quickshell.env("USER") || "root"]

        stdout: StdioCollector {
            onStreamFinished: {
                const rows = text.trim().split("\n").filter(l => /^\s*\d{4}-\d{2}-\d{2}/.test(l));
                root.pamRecord = rows.length > 0;
            }
        }
    }

    // only used when pam has already locked us out (needs admin auth)
    Process {
        id: resetProc
    }

    // battery straight from sysfs (no upower daemon needed)
    property real batPct: -1
    property bool batCharging: false

    Process {
        id: batProc
        running: root.showBattery
        command: ["sh", "-c", 'for b in /sys/class/power_supply/BAT*; do [ -r "$b/capacity" ] || continue; echo "$(cat "$b/capacity") $(cat "$b/status")"; exit 0; done']

        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(" ");
                const v = parseInt(p[0]);
                if (p.length >= 2 && !isNaN(v)) {
                    root.batPct = v;
                    root.batCharging = p[1] === "Charging";
                } else {
                    root.batPct = -1;
                }
            }
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: sessionLock.locked && root.showBattery
        onTriggered: if (!batProc.running) batProc.running = true
    }

    IpcHandler {
        target: "lock"
        function lock(): void {
            sessionLock.locked = true;
        }
    }

    Component.onCompleted: {
        if (root.oneshot)
            sessionLock.locked = true;
    }

    // ---------- the lock ----------
    WlSessionLock {
        id: sessionLock

        onLockedChanged: {
            if (locked) {
                root.buffer = "";
                root.reveal = false;
                root.failed = false;
                root.checking = false;
                root.unlocking = false;
                root.cooldown = 0;
                root.confirmArmed = false;
                confirmTimer.stop();
                failReset.stop();
                refreshFailTally();
                wpFile.reload();
                wakeScreen();
                if (root.showBattery && !batProc.running)
                    batProc.running = true;
            } else {
                wakeScreen();
            }
        }

        WlSessionLockSurface {
            id: lockSurface
            color: Theme.black


            Item {
                id: scene
                anchors.fill: parent
                focus: true
                // fade the whole scene in so engaging the lock is a transition, not a cut
                opacity: root.unlocking ? 0 : scene.intro

                // the compositor needs a moment to map the lock surface, animations
                // started earlier would just play out behind a black screen
                Timer {
                    interval: 40
                    running: lockSurface.visible
                    onTriggered: scene.arm()
                }

                property bool armed: false
                function arm() {
                    if (scene.armed)
                        return;
                    scene.armed = true;
                }

                property real intro: 0
                NumberAnimation on intro {
                    running: scene.armed
                    from: 0
                    to: 1
                    duration: 220
                    easing.type: Easing.OutQuad
                }

                // pill bar -> card morph, then the staged reveal
                property real openW: 0
                property real openH: 0
                readonly property real morph: Math.min(1, (openW + openH) / 2)
                readonly property bool shown: scene.armed && !root.unlocking
                onShownChanged: {
                    if (shown) {
                        closeAnim.stop();
                        openAnim.restart();
                    } else if (armed) {
                        openAnim.stop();
                        closeAnim.restart();
                    }
                }

                // pops wide like the pill bar does, then drops open
                ParallelAnimation {
                    id: openAnim
                    NumberAnimation { target: scene; property: "openW"; to: 1; duration: 380; easing.type: Easing.OutCubic }
                    SequentialAnimation {
                        PauseAnimation { duration: 100 }
                        NumberAnimation { target: scene; property: "openH"; to: 1; duration: 440; easing.type: Easing.OutCubic }
                    }
                }

                // unlock: card folds back into the pill before the scene fades
                ParallelAnimation {
                    id: closeAnim
                    NumberAnimation { target: scene; property: "openH"; to: 0; duration: 300; easing.type: Easing.InOutCubic }
                    SequentialAnimation {
                        PauseAnimation { duration: 90 }
                        NumberAnimation { target: scene; property: "openW"; to: 0; duration: 280; easing.type: Easing.InOutCubic }
                    }
                }
                // content only shows once the shape is (almost) the card
                readonly property real reveal: Math.max(0, Math.min(1, (openH - 0.55) / 0.45))

                // 0 -> 1 entrance progress: blur-in + staggered reveal
                property real enter: 0
                NumberAnimation on enter {
                    running: scene.armed
                    from: 0
                    to: 1
                    duration: 950
                    easing.type: Easing.OutCubic
                }

                property real contentIn: 0
                SequentialAnimation {
                    running: scene.armed
                    PauseAnimation { duration: 180 }
                    NumberAnimation { target: scene; property: "contentIn"; from: 0; to: 1; duration: 620; easing.type: Easing.OutCubic }
                }

                function stage(i) {
                    return Math.max(0, Math.min(1, scene.contentIn * 1.5 - i * 0.25));
                }

                Behavior on opacity {
                    NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                }

                Component.onCompleted: forceActiveFocus()

                // any input wakes the screen: keys (above), mouse move, click, wheel
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    hoverEnabled: true
                    onPositionChanged: root.activity()
                }

                TapHandler {
                    onTapped: root.activity()
                }

                WheelHandler {
                    onWheel: root.activity()
                }

                Keys.onPressed: event => {
                    event.accepted = true;
                    root.activity();
                    if (root.checking || root.unlocking)
                        return;
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.submit();
                        return;
                    }
                    if (root.lockedOut || root.pamLocked)
                        return;
                    root.confirmArmed = false;
                    if (event.key === Qt.Key_Backspace) {
                        root.buffer = root.buffer.slice(0, -1);
                    } else if (event.key === Qt.Key_Escape
                               || (event.key === Qt.Key_U && (event.modifiers & Qt.ControlModifier))) {
                        root.buffer = "";
                    } else if (event.key === Qt.Key_V && (event.modifiers & Qt.ControlModifier)) {
                        if (root.buffer.length > 0)
                            root.reveal = !root.reveal;
                    } else if (event.text.length > 0 && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                        const ch = event.text.charCodeAt(0);
                        if (ch >= 32 && ch !== 127) {
                            root.buffer += event.text;
                            root.failed = false;
                            failReset.restart();
                        }
                    }
                }

                // ----- background: gradient fallback, blurred wallpaper on top -----
                Rectangle {
                    anchors.fill: parent
                    color: th.bg
                }

                Image {
                    anchors.fill: parent
                    source: root.wallpaper !== "" ? "file://" + encodeURI(root.wallpaper) : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    sourceSize.width: 1920
                    scale: 1.10          // hides the dark edge the blur leaves behind
                    opacity: status === Image.Ready ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: 220 }
                    }

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        autoPaddingEnabled: false
                        blurEnabled: true
                        blurMax: 30
                        blur: Math.min(1, scene.enter * 1.35)
                        saturation: 0.03
                        brightness: -0.12
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(th.bg.r, th.bg.g, th.bg.b, 0.28)
                }

                // ----- reusable bits -----
                component T: Text {
                    font.family: root.textFont
                    color: th.fg
                    font.pixelSize: 16   // Monocraft is a pixel font: stick to multiples of 8 (16/24/80...)
                    renderType: Text.NativeRendering
                }

                // Nerd Font icon
                component I: Text {
                    font.family: root.nerdFont
                    color: th.fg
                    font.pixelSize: 16
                    renderType: Text.NativeRendering
                }

                component Pill: Rectangle {
                    id: pill
                    default property alias content: row.data
                    property bool interactive: false
                    property color accent: th.hi
                    property bool highlighted: false
                    readonly property bool hovered: area.containsMouse
                    signal clicked

                    implicitWidth: row.implicitWidth + 32
                    implicitHeight: 40
                    width: implicitWidth
                    height: implicitHeight
                    radius: 14
                    color: highlighted ? Qt.rgba(th.error.r, th.error.g, th.error.b, 0.40)
                        : hovered && interactive ? th.surfaceHi
                        : th.panel
                    border.width: highlighted || (hovered && interactive) ? 1.5 : 1
                    border.color: highlighted ? pill.accent : (hovered && interactive ? pill.accent : th.stroke)
                    scale: (area.pressed ? 0.92 : (hovered && interactive ? 1.03 : 1))

                    Behavior on color {
                        ColorAnimation { duration: 100 }
                    }
                    Behavior on border.color {
                        ColorAnimation { duration: 100 }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: 100 }
                    }
                    Behavior on width {
                        NumberAnimation { duration: 100 }
                    }

                    RowLayout {
                        id: row
                        anchors.centerIn: parent
                        spacing: 8
                    }

                    MouseArea {
                        id: area
                        anchors.fill: parent
                        enabled: pill.interactive
                        hoverEnabled: true
                        cursorShape: pill.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: pill.clicked()
                    }
                }

                // click once to arm (red, "sure?"), click again to fire; skips arming if confirmPowerActions is false
                component PowerPill: Pill {
                    id: pp
                    property string glyph: ""
                    property var cmd: []
                    property bool armed: false

                    interactive: true
                    highlighted: armed
                    scale: 1

                    onClicked: {
                        if (armed || !root.confirmPower) {
                            armTimer.stop();
                            armed = false;
                            powerProc.command = cmd;
                            powerProc.running = true;
                        } else {
                            armed = true;
                            armTimer.restart();
                        }
                    }

                    Timer {
                        id: armTimer
                        interval: 2600
                        onTriggered: pp.armed = false
                    }

                    I { text: pp.glyph; color: (pp.hovered || pp.armed) ? pp.accent : th.fg }
                    T { text: "sure?"; visible: pp.armed }
                }

                // ----- everything below lives in a resolution-scaled layer -----
                Item {
                    id: ui
                    readonly property real k: root.dpiScale   // no resolution scaling: scaling blurs pixel fonts
                    width: scene.width / k
                    height: scene.height / k
                    scale: k
                    transformOrigin: Item.TopLeft

                    // the box (shakes on a wrong password)
                    Item {
                        id: boxWrap
                        property real shakeOff: 0
                        width: box.width
                        height: box.height
                        x: (ui.width - width) / 2 + shakeOff
                        y: (ui.height - height) / 2
                        opacity: Math.min(1, scene.morph * 8)
                        scale: 0.985 + 0.015 * scene.morph

                        Connections {
                            target: root
                            function onShake() { shakeAnim.restart(); }
                        }

                        SequentialAnimation {
                            id: shakeAnim
                            NumberAnimation { target: boxWrap; property: "shakeOff"; to: -22; duration: 50 }
                            NumberAnimation { target: boxWrap; property: "shakeOff"; to: 20; duration: 70 }
                            NumberAnimation { target: boxWrap; property: "shakeOff"; to: -12; duration: 70 }
                            NumberAnimation { target: boxWrap; property: "shakeOff"; to: 6; duration: 60 }
                            NumberAnimation { target: boxWrap; property: "shakeOff"; to: 0; duration: 60 }
                        }

                        RectangularShadow {
                            property real t: Config.showShadows ? 1 : 0
                            Behavior on t { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                            anchors.fill: box
                            radius: box.radius
                            blur: 18 + 32 * scene.morph
                            spread: 1 + 2 * scene.morph
                            offset: Qt.vector2d(0, 4 + 14 * scene.morph)
                            color: Qt.rgba(0, 0, 0, 0.5)
                            opacity: Math.min(1, scene.morph * 2.5) * t
                        }

                        Rectangle {
                            id: box
                            clip: true
                            readonly property real finalW: 800
                            readonly property real finalH: col.implicitHeight + 36
                            readonly property real finalR: 30

                            width: root.pillW + (finalW - root.pillW) * scene.openW
                            height: root.pillH + (finalH - root.pillH) * scene.openH
                            radius: root.pillR + (finalR - root.pillR) * Math.min(1, scene.openH)
                            color: th.surface
                            border.width: 1
                            border.color: th.stroke

                            Column {
                                id: col
                                x: 18
                                y: 18
                                width: box.finalW - 36
                                spacing: 14
                                opacity: scene.reveal

                                Row {
                                    id: panels
                                    width: parent.width
                                    height: 304
                                    spacing: 16

                                    // ---- left: clock ----
                                    Rectangle {
                                        id: leftP
                                        width: 360
                                        height: parent.height

                                        // type scales with the box and the shell's dpi setting, so the
                                        // clock/date/greeting stay in proportion on any resolution
                                        // no media card -> give the clock block a bit more presence
                                        readonly property real typeScale: root.mediaShown ? 1.0 : 1.18
                                        readonly property real clockSize: Math.max(24, Math.min(72,
                                            Math.round(Math.min(height * 0.105, width * 0.10) * Config.dpiScale * typeScale)))
                                        readonly property real dateSize: Math.max(13, Math.round(clockSize * 0.56))
                                        readonly property real greetingSize: Math.max(10, Math.round(clockSize * 0.375))
                                        radius: 20
                                        color: th.panel
                                        border.width: 1
                                        border.color: th.stroke
                                        opacity: scene.stage(1)
                                        transform: Translate { x: (1 - scene.stage(1)) * -16 }

                                        Column {
                                            anchors.centerIn: parent
                                            width: parent.width - 48
                                            // one spacing drives every gap: clock -> date -> greeting -> media
                                            spacing: 12

                                            Item {
                                                width: parent.width
                                                height: clockText.implicitHeight - Math.round((clockText.implicitHeight - leftP.clockSize) / 2)

                                                T {
                                                    id: clockText
                                                    anchors.bottom: parent.bottom
                                                    width: parent.width
                                                    horizontalAlignment: Text.AlignHCenter
                                                    text: Qt.formatDateTime(clock.date, root.clockFmt)
                                                    font.pixelSize: mediaActive ? 32 : 40
                                                    fontSizeMode: Text.Fit
                                                    minimumPixelSize: 30
                                                }
                                            }

                                            Item {
                                                width: parent.width
                                                height: dateText.implicitHeight - Math.round((dateText.implicitHeight - leftP.dateSize) / 2)

                                                T {
                                                    id: dateText
                                                    anchors.bottom: parent.bottom
                                                    width: parent.width
                                                    horizontalAlignment: Text.AlignHCenter
                                                    text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                                                    font.pixelSize: mediaActive ? 18 : 20
                                                    color: th.sub
                                                }
                                            }

                                            Item {
                                                width: parent.width
                                                height: greetingText.implicitHeight - Math.round((greetingText.implicitHeight - leftP.greetingSize) / 2)

                                                T {
                                                    id: greetingText
                                                    anchors.bottom: parent.bottom
                                                    // nudge the greeting down when it sits alone in the box
                                                    anchors.bottomMargin: root.mediaShown ? 0 : -6
                                                    width: parent.width
                                                    horizontalAlignment: Text.AlignHCenter
                                                    text: root.greeting()
                                                    font.pixelSize: mediaActive ? 12 : 14
                                                    color: th.hi
                                                    elide: Text.ElideRight
                                                }
                                            }

                                            // the shell's own media player card, same file the control
                                            // center uses. it collapses to 0 height when nothing plays.
                                            Item {
                                                id: mediaWrap
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                width: parent.width - 8
                                                height: root.mediaShown ? mediaCard.height : 0
                                                visible: height > 0

                                                RectangularShadow {
                                                    property real t: Config.showShadows ? 1 : 0
                                                    Behavior on t { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                                    anchors.fill: mediaCard
                                                    radius: mediaCard.radius
                                                    blur: 28
                                                    spread: 1.5
                                                    offset: Qt.vector2d(0, 8)
                                                    color: Qt.rgba(0, 0, 0, 0.60)
                                                    opacity: t
                                                }

                                                MediaPlayer {
                                                    id: mediaCard
                                                    host: "lockscreen"
                                                    width: parent.width
                                                    radius: 18
                                                    margin: 16
                                                }

                                                Connections {
                                                    target: mediaCard
                                                    function onHasPlayerChanged() {
                                                        root.mediaActive = mediaCard.hasPlayer;
                                                    }
                                                    Component.onCompleted: root.mediaActive = mediaCard.hasPlayer;
                                                }
                                            }
                                        }
                                    }

                                    // ---- right: login ----
                                    Rectangle {
                                        id: rightP
                                        width: parent.width - leftP.width - parent.spacing
                                        height: parent.height
                                        radius: 20
                                        color: th.panel
                                        border.width: 1
                                        border.color: th.stroke
                                        opacity: scene.stage(1)
                                        transform: Translate { x: (1 - scene.stage(1)) * 16 }

                                        Column {
                                            anchors.centerIn: parent
                                            width: parent.width - 48
                                            spacing: 14

                                            ClippingRectangle {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                width: 104
                                                height: 104
                                                radius: 52
                                                color: th.hi

                                                T {
                                                    anchors.centerIn: parent
                                                    text: root.userName.charAt(0).toUpperCase()
                                                    color: th.bg
                                                    font.pixelSize: 48
                                                    font.weight: Font.Bold
                                                }

                                                Image {
                                                    anchors.fill: parent
                                                    source: root.avatarPath !== "" ? "file://" + encodeURI(root.avatarPath) : ""
                                                    fillMode: Image.PreserveAspectCrop
                                                    asynchronous: true
                                                    visible: status === Image.Ready
                                                }
                                            }

                                            T {
                                                width: parent.width
                                                horizontalAlignment: Text.AlignHCenter
                                                text: root.userName
                                                font.pixelSize: 24
                                            }

                                            // password pill
                                            Rectangle {
                                                id: field
                                                width: parent.width
                                                height: 44
                                                radius: height / 2
                                                color: Qt.rgba(th.fg.r, th.fg.g, th.fg.b, 0.10)
                                                border.width: 1
                                                border.color: (root.failed || root.lockedOut) ? th.error : Qt.rgba(th.fg.r, th.fg.g, th.fg.b, 0.06)

                                                Behavior on border.color {
                                                    ColorAnimation { duration: 200 }
                                                }

                                                SequentialAnimation {
                                                    id: typePulse
                                                    NumberAnimation { target: field; property: "scale"; to: 1.012; duration: 90; easing.type: Easing.OutQuad }
                                                    NumberAnimation { target: field; property: "scale"; to: 1; duration: 160; easing.type: Easing.OutQuad }
                                                }

                                                Connections {
                                                    target: root
                                                    function onBufferChanged() {
                                                        if (root.buffer.length > 0)
                                                            typePulse.restart();
                                                    }
                                                }

                                                // centered placeholder, fades out once you type
                                                T {
                                                    anchors.centerIn: parent
                                                    text: "Enter Password"
                                                    color: th.sub
                                                    font.pixelSize: 16
                                                    opacity: root.buffer.length === 0 ? 0.85 : 0
                                                    Behavior on opacity {
                                                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                                    }
                                                }

                                                Item {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 46
                                                    anchors.rightMargin: 46
                                                    clip: true

                                                    Row {
                                                        visible: !root.reveal
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        spacing: 6

                                                        Repeater {
                                                            model: Math.min(root.buffer.length, 14)

                                                            // minimal bullets
                                                            Rectangle {
                                                                required property int index

                                                                readonly property int age: Math.min(root.buffer.length, 14) - 1 - index

                                                                width: 9
                                                                height: 9
                                                                radius: 4.5
                                                                color: root.failed ? th.error
                                            : Qt.rgba(th.hi.r, th.hi.g, th.hi.b, Math.max(0.55, 1 - age * 0.07))

                                                                property real pop: 0
                                                                opacity: 0.55 + 0.45 * pop
                                                                scale: 0.78 + 0.22 * pop

                                                                NumberAnimation on pop {
                                                                    from: 0
                                                                    to: 1
                                                                    duration: 320
                                                                    easing.type: Easing.OutCubic
                                                                }

                                                                Behavior on color {
                                                                    ColorAnimation { duration: 180 }
                                                                }
                                                            }
                                                        }
                                                    }

                                                    // revealed password, same spot the bullets sit in
                                                    T {
                                                        visible: root.reveal && root.buffer.length > 0
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        width: parent.width
                                                        horizontalAlignment: Text.AlignHCenter
                                                        elide: Text.ElideMiddle
                                                        color: root.failed ? th.error : th.hi
                                                        text: root.buffer
                                                        Behavior on color { ColorAnimation { duration: 180 } }
                                                    }
                                                }

                                                // eye toggle, same glyphs as the wifi password prompt
                                                I {
                                                    id: eyeBtn
                                                    readonly property bool live: root.buffer.length > 0 && !root.checking && !root.unlocking
                                                    anchors.right: goBtn.left
                                                    anchors.rightMargin: 8
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: root.reveal ? "\uf070" : "\uf06e" // eye-slash / eye
                                                    color: eyeArea.containsMouse ? th.hi : th.sub
                                                    font.pixelSize: 16
                                                    opacity: live ? 1 : 0
                                                    visible: opacity > 0

                                                    Behavior on opacity {
                                                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                                    }
                                                    Behavior on color { ColorAnimation { duration: 120 } }

                                                    MouseArea {
                                                        id: eyeArea
                                                        anchors.fill: parent
                                                        anchors.margins: -7
                                                        enabled: eyeBtn.live
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            root.reveal = !root.reveal;
                                                            scene.forceActiveFocus();
                                                        }
                                                    }
                                                }

                                                // arrow -> spinner -> check, only shows up once there is something to submit
                                                Rectangle {
                                                    id: goBtn
                                                    readonly property bool live: root.buffer.length > 0 || root.checking || root.unlocking || root.pamLocked
                                                    width: 30
                                                    height: 30
                                                    radius: 15
                                                    anchors.right: parent.right
                                                    anchors.rightMargin: 7
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    color: th.hi
                                                    opacity: live ? (root.lockedOut ? 0.4 : 1) : 0
                                                    scale: goArea.pressed ? 0.9 : (live ? 1 : 0.6)

                                                    Behavior on opacity {
                                                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                                    }
                                                    Behavior on scale {
                                                        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                                                    }

                                                    I {
                                                        id: goIcon
                                                        anchors.centerIn: parent
                                                        text: root.unlocking ? "\uf00c" : root.checking ? "\uf110" : root.pamLocked ? "\uf023" : "\uf061"
                                                        color: th.bg
                                                        font.pixelSize: 16

                                                        NumberAnimation on rotation {
                                                            running: root.checking
                                                            from: 0
                                                            to: 360
                                                            duration: 900
                                                            loops: Animation.Infinite
                                                            onRunningChanged: if (!running) goIcon.rotation = 0
                                                        }
                                                    }

                                                    MouseArea {
                                                        id: goArea
                                                        anchors.fill: parent
                                                        enabled: goBtn.live && !root.lockedOut
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            root.submit();
                                                            scene.forceActiveFocus();
                                                        }
                                                    }
                                                }
                                            }

                                            RowLayout {
                                                width: parent.width
                                                spacing: 6

                                                I {
                                                    visible: root.failed || root.lockedOut
                                                    text: "\uf071"
                                                    color: th.error
                                                    font.pixelSize: 16
                                                    Layout.alignment: Qt.AlignVCenter
                                                }

                                                T {
                                                    Layout.fillWidth: true
                                                    Layout.alignment: Qt.AlignVCenter
                                                    horizontalAlignment: Text.AlignHCenter
                                                    wrapMode: Text.WordWrap
                                                    font.pixelSize: 12
                                                    color: (root.failed || root.lockedOut) ? th.error : th.sub
                                                    text: root.statusText
                                                }
                                            }
                                        }
                                    }
                                }

                                // ---- bottom strip: weather + battery left, power right ----
                                Item {
                                    id: bottomBar
                                    width: parent.width
                                    height: 48
                                    opacity: scene.stage(2)
                                    transform: Translate { y: (1 - scene.stage(2)) * 10 }

                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 10

                                        Pill {
                                            visible: root.wOk

                                            I { text: root.wGlyph; color: root.wGlyphColor; font.pixelSize: 24; height: 20; verticalAlignment: Text.AlignVCenter }
                                            T { text: Math.round(root.wTemp) + root.wUnit; height: 20; verticalAlignment: Text.AlignVCenter }
                                        }

                                        Pill {
                                            visible: root.showBattery && root.batPct >= 0

                                            I { text: root.batteryGlyph(root.batPct); color: root.batteryColor(root.batPct); font.pixelSize: 24; height: 20; verticalAlignment: Text.AlignVCenter }
                                            T { text: root.batPct + "%"; height: 20; verticalAlignment: Text.AlignVCenter }
                                        }
                                    }

                                    Row {
                                        anchors.right: parent.right
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 10
                                        // shared machines: nobody should be able to shut the box down from the lock
                                        visible: Config.lockscreenPowerActions

                                        PowerPill { glyph: "\uf186"; accent: Theme.powerSleep; cmd: ["systemctl", "suspend"] }
                                        PowerPill { glyph: "\uf021"; accent: Theme.powerRestart; cmd: ["systemctl", "reboot"] }
                                        PowerPill { glyph: "\uf011"; accent: Theme.powerShutdown; cmd: ["systemctl", "poweroff"] }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
