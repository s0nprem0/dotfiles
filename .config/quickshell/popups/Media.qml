import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../components"
import "../service"
import "media" as MediaComponents

PopupPanel {
    id: root

    // ── Configuration ──
    anchorSide: "right"
    panelWidth: 340
    panelMaxHeight: 0
    finalInset: 32
    introDuration: 120
    exitDuration: 100
    contentMargin: 10

    // ── State ──
    property string playerName: ""
    property string playerStatus: ""
    property string artist: ""
    property string title: ""
    property string album: ""
    property string artUrl: ""
    property bool hasPlayer: false
    property var availablePlayers: []
    property double volume: 0
    property double position: 0
    property double trackLength: 0

    onBeforeOpen: { refreshSinks() }

    Component.onCompleted: refreshSinks()

    function formatTime(seconds) {
        if (typeof seconds !== "number" || seconds < 0) return "0:00"
        var m = Math.floor(seconds / 60)
        var s = Math.floor(seconds % 60)
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    // ── System Volume (state pushed from Audio bar module) ──
    property double sysVol: 0
    property bool sysMuted: false

    // ── Mic Volume (state pushed from Audio bar module) ──
    property double micVol: 100
    property bool micMuted: false

    // ── Source switch animation ──
    property bool mediaSwitching: false
    property real mediaFade: 1
    property real mediaSlide: 0

    // ── Audio bar ref (immediate volume reflection) ──
    property var audioBarRef: null

    // ── Volume batch pending values ──
    property double pendingOutVol: -1
    property double pendingInVol: -1
    property var pendingAppVols: ({})

    Process { id: sysVolAction }

    Process { id: micVolAction }

    // ── Volume batch timer: applies pending changes every 150ms ──
    Timer {
        id: volumeApplyTimer
        interval: 150
        repeat: true
        running: root.pendingOutVol !== -1 || root.pendingInVol !== -1 || Object.keys(root.pendingAppVols).length > 0
        onTriggered: {
            var needsRefresh = false
            if (root.pendingOutVol !== -1) {
                var pct = Math.round(root.pendingOutVol * 100)
                sysVolAction.command = ["wpctl", "set-volume", "-l", "1.5", "@DEFAULT_AUDIO_SINK@", pct + "%"]
                sysVolAction.running = true
                if (root.audioBarRef) {
                    root.audioBarRef.vol = Math.round(root.pendingOutVol * 100)
                    root.audioBarRef.isMuted = false
                }
                root.pendingOutVol = -1
                needsRefresh = true
            }
            if (root.pendingInVol !== -1) {
                var pct2 = Math.round(root.pendingInVol * 100)
                micVolAction.command = ["wpctl", "set-volume", "-l", "1.5", "@DEFAULT_AUDIO_SOURCE@", pct2 + "%"]
                micVolAction.running = true
                root.pendingInVol = -1
                needsRefresh = true
            }
            var appKeys = Object.keys(root.pendingAppVols)
            if (appKeys.length > 0) {
                var cmds = []
                for (var i = 0; i < appKeys.length; i++) {
                    var appIdx = appKeys[i]
                    var appPct = Math.round(root.pendingAppVols[appIdx] * 100)
                    cmds.push("pactl set-sink-input-volume " + appIdx + " " + appPct + "%")
                    delete root.pendingAppVols[appIdx]
                }
                setAppVolProc.command = ["sh", "-c", cmds.join("; ")]
                setAppVolProc.running = true
                needsRefresh = true
            }
            if (needsRefresh) refreshSinks()
        }
    }

    function setSysVol(frac) {
        frac = Math.max(0, Math.min(1, frac))
        root.pendingOutVol = frac
        root.sysVol = Math.round(frac * 100)
    }

    function setMicVol(frac) {
        frac = Math.max(0, Math.min(1, frac))
        root.pendingInVol = frac
        root.micVol = Math.round(frac * 100)
    }

    // ── Unified audio status via Rust helper ──
    property var sinkList: []
    property string activeSinkId: ""
    property var sourceList: []
    property string activeSourceId: ""
    property var appList: []
    property var diagnostics: ({})

    Process {
        id: statusProc
        command: [Theme.bin("get_audio_status")]
        running: false
        stdout: StdioCollector {}
        onExited: {
            var out = stdout.text.trim()
            if (!out) return
            try {
                var d = JSON.parse(out)
                if (!d) return

                // Sinks
                var newSinks = []
                var newActiveSink = ""
                for (var si = 0; si < d.sinks.length; si++) {
                    var s = d.sinks[si]
                    newSinks.push(s.index + "||" + (s.description || s.name))
                }
                if (d.default_sink) {
                    newActiveSink = String(d.default_sink.index)
                    root.sysVol = d.default_sink.volume
                    root.sysMuted = d.default_sink.muted
                    root.isBtSink = d.default_sink.is_bluetooth
                }
                root.sinkList = newSinks
                root.activeSinkId = newActiveSink

                // Sources
                var newSources = []
                var newActiveSource = ""
                for (var si2 = 0; si2 < d.sources.length; si2++) {
                    var src = d.sources[si2]
                    newSources.push(src.index + "||" + (src.description || src.name))
                }
                if (d.default_source) {
                    newActiveSource = String(d.default_source.index)
                    root.micVol = d.default_source.volume
                    root.micMuted = d.default_source.muted
                }
                root.sourceList = newSources
                root.activeSourceId = newActiveSource

                // Apps
                var newApps = []
                for (var ai = 0; ai < d.apps.length; ai++) {
                    var a = d.apps[ai]
                    newApps.push(a.index + "||" + a.name + "||" + a.volume + "||" + a.muted)
                }
                root.appList = newApps

                // Diagnostics
                root.diagnostics = d.diagnostics || {}

                // Media
                if (d.media) {
                    var m = d.media
                    root.hasPlayer = true
                    root.playerName = m.player || ""
                    root.playerStatus = m.status || ""
                    root.artist = m.artist || ""
                    root.title = m.title || ""
                    root.trackLength = (m.length || 0) * 1000000
                    root.position = m.position || 0
                    root.volume = m.volume || 0
                    var newArt = m.art_url || ""
                    if (newArt !== root.artUrl) {
                        if (newArt.indexOf("http") === 0) {
                            artCache.ensureCached(newArt)
                        } else {
                            root.artUrl = newArt
                        }
                    }
                } else {
                    root.hasPlayer = false
                    root.playerName = ""
                    root.playerStatus = ""
                    root.artist = ""
                    root.title = ""
                    root.artUrl = ""
                    root.trackLength = 0
                    root.position = 0
                }

                // Available media players
                var players = []
                for (var pi = 0; pi < d.media_sources.length; pi++) {
                    players.push(d.media_sources[pi].name)
                }
                root.availablePlayers = players

                // Restore player name if current one is missing
                if (root.hasPlayer && players.length > 0
                    && players.indexOf(root.playerName) === -1) {
                    root.playerName = players[0]
                }
            } catch (e) {
                console.warn("Media: failed to parse audio status:", e)
            }
        }
    }

    Process {
        id: setSinkProc
        running: false
    }

    function refreshSinks() {
        statusProc.running = true
    }

    function refreshSources() {
        statusProc.running = true
    }

    function refresh() {
        statusProc.running = true
    }

    function setDefaultSink(id) {
        resetSinkTimer.restart()
        setSinkProc.command = ["pactl", "set-default-sink", id]
        setSinkProc.running = true
    }

    Timer {
        id: resetSinkTimer
        interval: 150
        onTriggered: refreshSinks()
    }

    Process {
        id: setSourceProc
        running: false
    }

    function setDefaultSource(id) {
        resetSourceTimer.restart()
        setSourceProc.command = ["pactl", "set-default-source", id]
        setSourceProc.running = true
    }

    Timer {
        id: resetSourceTimer
        interval: 150
        onTriggered: refreshSinks()
    }

    // ── Auto-refresh while open ──
    Timer {
        id: refreshTimer
        interval: 2000
        repeat: true
        running: root.showPopup && root.hasPlayer
        onTriggered: refreshSinks()
    }

    Timer {
        id: sinkRefreshTimer
        interval: 4000
        repeat: true
        running: root.showPopup && !root.hasPlayer
        onTriggered: refreshSinks()
    }

    Process { id: setAppVolProc }
    Process { id: setAppMuteProc }

    function setAppVol(id, frac) {
        frac = Math.max(0, Math.min(1, frac))
        root.pendingAppVols[String(id)] = frac
    }

    function toggleAppMute(id) {
        setAppMuteProc.command = ["pactl", "set-sink-input-mute", String(id), "toggle"]
        setAppMuteProc.running = true
        refreshSinks()
    }

    // ── Position advancement: smooth seek bar while playing ──
    Timer {
        id: mediaPositionTimer
        interval: 500
        repeat: true
        running: root.hasPlayer && root.playerStatus === "Playing"
        onTriggered: {
            if (root.playerStatus === "Playing") {
                var newPos = root.position + 0.5
                if (root.trackLength > 0) {
                    if (newPos > root.trackLength / 1000000)
                        newPos = root.trackLength / 1000000
                } else if (newPos > 3600) {
                    newPos = 3600
                }
                root.position = newPos
            }
        }
    }

    // ── Media source switch animation ──
    function switchMediaSource() {
        if (root.mediaSwitching || root.availablePlayers.length <= 1) return
        root.mediaSwitching = true
        switchAnim.restart()
    }

    function applyMediaSourceSwitch() {
        var list = root.availablePlayers
        var idx = list.indexOf(root.playerName)
        var nextIdx = (idx + 1) % list.length
        root.playerName = list[nextIdx]
        // Persist selection for next read
        persistPlayerProc.command = ["sh", "-c",
            "printf '%s' \"" + root.playerName.replace(/"/g, '\\"') + "\" > /tmp/quickshell_current_media_player"]
        persistPlayerProc.running = true
        refreshSinks()
    }

    Process { id: persistPlayerProc }

    SequentialAnimation {
        id: switchAnim
        ParallelAnimation {
            NumberAnimation { target: root; property: "mediaFade"; from: 1; to: 0; duration: 140; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "mediaSlide"; from: 0; to: -8; duration: 140; easing.type: Easing.OutCubic }
        }
        ScriptAction { script: root.applyMediaSourceSwitch() }
        PropertyAction { target: root; property: "mediaSlide"; value: 8 }
        ParallelAnimation {
            NumberAnimation { target: root; property: "mediaFade"; from: 0; to: 1; duration: 240; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "mediaSlide"; from: 8; to: 0; duration: 240; easing.type: Easing.OutCubic }
        }
        ScriptAction { script: root.mediaSwitching = false }
    }

    // ── Bluetooth detection ──
    property bool isBtSink: false

    // ── Art cache download ──
    ArtCache {
        id: artCache
        cachePrefix: "media_art_"
        onCacheReady: function(url, localPath) {
            if (url === artCache.pendingUrl)
                root.artUrl = localPath
        }
    }

    // ── Player control process ──
    Process {
        id: ctlProc
        running: false
        onExited: { refreshSinks() }
    }

    function playerCtl(args) {
        if (!root.playerName) return
        ctlProc.command = ["playerctl", "-p", root.playerName].concat(args)
        ctlProc.running = true
    }

    // ── Content ──
    contentComponent: Component {
        FocusScope {
            implicitWidth: root.panelWidth - root.contentMargin * 2
            implicitHeight: mainColumn.implicitHeight

            Column {
                id: mainColumn
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 8

                // ── Section 1: Header ──
                Row {
                    width: parent.width
                    spacing: 6

                    Text {
                        text: "󰝚 Now Playing"
                        color: Theme.primary
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                        renderType: Text.NativeRendering
                    }

                    Item { width: parent.width - childrenRect.width - 20; height: 1 }

                    Text {
                        text: "✕"
                        color: Theme.primary
                        opacity: 0.5
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        anchors.verticalCenter: parent.verticalCenter
                        renderType: Text.NativeRendering

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closePopup()
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.primary
                    opacity: 0.25
                }

                // ── No Player State ──
                Text {
                    width: parent.width
                    visible: !root.hasPlayer
                    text: "No media players detected"
                    color: Theme.primary
                    opacity: 0.5
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    renderType: Text.NativeRendering
                }

                // ── Player Selector ──
                Rectangle {
                    visible: root.hasPlayer && root.availablePlayers.length > 1
                    width: parent.width
                    height: 22
                    color: "transparent"

                    RowLayout {
                        anchors.fill: parent
                        spacing: 4

                        Text {
                            text: "Player:"
                            color: Theme.primary
                            opacity: 0.5
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            renderType: Text.NativeRendering
                        }

                        Repeater {
                            model: root.availablePlayers
                            delegate: Rectangle {
                                id: playerBtn
                                required property string modelData
                                height: 20
                                width: playerLabel.implicitWidth + 12
                                radius: 0
                                color: modelData === root.playerName ? Qt.alpha(Theme.primary, 0.25)
                                     : playerBtnMa.containsMouse ? Qt.alpha(Theme.primary, 0.1)
                                     : "transparent"
                                border.width: modelData === root.playerName ? 1
                                     : playerBtnMa.containsMouse ? 1
                                     : 0
                                border.color: Qt.alpha(Theme.primary, 0.4)

                                Text {
                                    id: playerLabel
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: modelData === root.playerName ? Theme.primary
                                         : playerBtnMa.containsMouse ? Theme.primary
                                         : Qt.alpha(Theme.primary, 0.5)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    renderType: Text.NativeRendering
                                }

                                MouseArea {
                                    id: playerBtnMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.playerName = modelData
                                            persistPlayerProc.command = ["sh", "-c",
                                                "printf '%s' \"" + modelData.replace(/"/g, '\\"') + "\" > /tmp/quickshell_current_media_player"]
                                            persistPlayerProc.running = true
                                            root.refreshSinks()
                                        }
                                }
                            }
                        }
                    }
                }

                MediaComponents.PlayerSection {
                    mediaRoot: root
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.primary
                    opacity: 0.25
                }

                // ── System Volume ──
                Column {
                    width: parent.width
                    spacing: 4

                    Row {
                        width: parent.width

                        Text {
                            text: (root.sysMuted ? "󰝟" : (root.isBtSink ? "󰋋" : "󰕾")) + " Output: " + (root.sysMuted ? "Muted" : Math.round(root.sysVol) + "%")
                            color: Theme.primary
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                            renderType: Text.NativeRendering
                        }

                        Item { width: parent.width - childrenRect.width - muteSysText.width; height: 1 }

                        Text {
                            id: muteSysText
                            text: root.sysMuted ? "Unmute" : "Mute"
                            color: Theme.primary
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            anchors.verticalCenter: parent.verticalCenter
                            renderType: Text.NativeRendering

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: {
                                    sysVolAction.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
                                    sysVolAction.running = true
                                    if (root.audioBarRef) {
                                        root.audioBarRef.isMuted = !root.sysMuted
                                    }
                                    root.sysMuted = !root.sysMuted
                                    refreshSinks()
                                }
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 8

                        BlockSlider {
                            currentVal: root.sysMuted ? 0 : Math.min(1, root.sysVol / 100)
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            emptyColor: Theme.surface
                        }

                        MouseArea {
                            anchors.fill: parent
                            preventStealing: true
                            onPressed: root.setSysVol(mouse.x / width)
                            onPositionChanged: if (pressed) {
                                var v = Math.min(1, Math.max(0, mouse.x / width))
                                if (Math.abs(v - root.sysVol / 100) > 0.02) root.setSysVol(v)
                            }
                        }

                        WheelHandler {
                            acceptedDevices: PointerDevice.Mouse
                            onWheel: function(event) {
                                var delta = event.angleDelta.y / 120
                                var cur = root.sysMuted ? 0 : Math.min(1, root.sysVol / 100)
                                var newVol = Math.max(0, Math.min(1, cur + delta * 0.05))
                                root.setSysVol(newVol)
                            }
                        }
                    }

                    // ── Audio Devices ──
                    Column {
                        width: parent.width
                        spacing: 4
                        visible: root.sinkList.length > 0

                        Row {
                            width: parent.width
                            spacing: 4

                            Text {
                                text: "󰓃 Output"
                                color: Theme.primary
                                opacity: 0.5
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                                renderType: Text.NativeRendering
                            }

                            Item { width: parent.width - childrenRect.width; height: 1 }
                        }

                        Flow {
                            width: parent.width
                            spacing: 4

                            Repeater {
                                model: root.sinkList
                                delegate: Rectangle {
                                    required property string modelData
                                    id: deviceChip
                                    height: 20
                                    width: deviceLabel.implicitWidth + 10
                                    radius: 0
                                    color: isActive ? Qt.alpha(Theme.primary, 0.2)
                                         : chipHover.containsMouse ? Qt.alpha(Theme.primary, 0.08)
                                         : "transparent"
                                    border.width: 1
                                    border.color: isActive ? Qt.alpha(Theme.primary, 0.5)
                                              : chipHover.containsMouse ? Qt.alpha(Theme.primary, 0.2)
                                              : Qt.alpha(Theme.primary, 0.1)

                                    property string sinkId: modelData.split("||")[0].trim()
                                    property string sinkName: modelData.split("||")[1].trim()
                                    property bool isActive: root.activeSinkId === sinkId

                                    Text {
                                        id: deviceLabel
                                        anchors.centerIn: parent
                                        text: parent.sinkName
                                        color: parent.isActive ? Theme.primary : Qt.alpha(Theme.primary, 0.6)
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 9
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        renderType: Text.NativeRendering
                                    }

                                    MouseArea {
                                        id: chipHover
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onClicked: root.setDefaultSink(parent.sinkId)
                                    }
                                }
                            }
                        }

                        Row {
                             width: parent.width
                             spacing: 4
                             visible: root.sourceList.length > 0

                            Text {
                                text: "󰍬 Input"
                                color: Theme.primary
                                opacity: 0.5
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                                renderType: Text.NativeRendering
                            }

                            Item { width: parent.width - childrenRect.width; height: 1 }
                        }

                        Flow {
                            width: parent.width
                            spacing: 4
                            visible: root.sourceList.length > 0

                            Repeater {
                                model: root.sourceList
                                delegate: Rectangle {
                                    required property string modelData
                                    height: 20
                                    width: srcLabel.implicitWidth + 10
                                    radius: 0
                                    color: isActive ? Qt.alpha(Theme.primary, 0.2)
                                         : srcHover.containsMouse ? Qt.alpha(Theme.primary, 0.08)
                                         : "transparent"
                                    border.width: 1
                                    border.color: isActive ? Qt.alpha(Theme.primary, 0.5)
                                              : srcHover.containsMouse ? Qt.alpha(Theme.primary, 0.2)
                                              : Qt.alpha(Theme.primary, 0.1)

                                    property string srcId: modelData.split("||")[0].trim()
                                    property string srcName: modelData.split("||")[1].trim()
                                    property bool isActive: root.activeSourceId === srcId

                                    Text {
                                        id: srcLabel
                                        anchors.centerIn: parent
                                        text: parent.srcName
                                        color: parent.isActive ? Theme.primary : Qt.alpha(Theme.primary, 0.6)
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 9
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        renderType: Text.NativeRendering
                                    }

                                    MouseArea {
                                        id: srcHover
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onClicked: root.setDefaultSource(parent.srcId)
                                    }
                                }
                            }
                        }
                    }

                    // ── Mic Input ──
                    Column {
                        width: parent.width
                        spacing: 4

                        Row {
                            width: parent.width

                            Text {
                                text: (root.micMuted ? "󰍭" : "󰍬") + " Input: " + (root.micMuted ? "Muted" : Math.round(root.micVol) + "%")
                                color: Theme.primary
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                                renderType: Text.NativeRendering
                            }

                            Item { width: parent.width - childrenRect.width - muteMicText.width; height: 1 }

                            Text {
                                id: muteMicText
                                text: root.micMuted ? "Unmute" : "Mute"
                                color: Theme.primary
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                anchors.verticalCenter: parent.verticalCenter
                                renderType: Text.NativeRendering

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                onClicked: {
                                    micVolAction.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]
                                    micVolAction.running = true
                                    root.micMuted = !root.micMuted
                                    refreshSinks()
                                }
                                }
                            }
                        }

                        Item {
                            width: parent.width
                            height: 8

                            Row {
                                id: micBlocks
                                property double currentVal: root.micMuted ? 0 : Math.min(1, root.micVol / 100)

                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                height: 5
                                spacing: 1

                                Repeater {
                                    model: 15
                                    delegate: Rectangle {
                                        height: parent.height
                                        width: (micBlocks.width - (micBlocks.spacing * 14)) / 15
                                        radius: 0
                                        color: index < Math.round(micBlocks.currentVal * 15) ? Theme.primary : Theme.surface
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                preventStealing: true
                                onPressed: root.setMicVol(mouse.x / width)
                                onPositionChanged: if (pressed) root.setMicVol(mouse.x / width)
                            }

                            WheelHandler {
                                acceptedDevices: PointerDevice.Mouse
                                onWheel: function(event) {
                                    var delta = event.angleDelta.y / 120
                                    var cur = root.micMuted ? 0 : Math.min(1, root.micVol / 100)
                                    var newVol = Math.max(0, Math.min(1, cur + delta * 0.05))
                                    root.setMicVol(newVol)
                                }
                            }
                        }
                    }
                }

                    // ── App Volumes ──
                    Column {
                        width: parent.width
                        spacing: 4
                        visible: root.appList.length > 0

                        Text {
                            text: "App Volumes"
                            color: Theme.primary
                            opacity: 0.5
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.bold: true
                            renderType: Text.NativeRendering
                        }

                        Repeater {
                            model: root.appList
                            delegate: Item {
                                required property string modelData
                                width: parent.width
                                height: 32

                                property var parts: modelData.split("||")
                                property int appIndex: parseInt(parts[0])
                                property string appName: parts[1] || "Unknown"
                                property int appVol: parseInt(parts[2]) || 0
                                property bool appMuted: parts[3] === "true"

                                Column {
                                    width: parent.width
                                    spacing: 2

                                    RowLayout {
                                        width: parent.width
                                        spacing: 6

                                        Text {
                                            text: parent.parent.parent.appName
                                            Layout.maximumWidth: 100
                                            color: Theme.primary
                                            opacity: 0.7
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 9
                                            elide: Text.ElideRight
                                            Layout.alignment: Qt.AlignVCenter
                                            renderType: Text.NativeRendering
                                        }

                                        Text {
                                            text: parent.parent.parent.appMuted ? "Muted" : parent.parent.parent.appVol + "%"
                                            color: parent.parent.parent.appMuted ? Theme.muted : Theme.primary
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 8
                                            Layout.alignment: Qt.AlignVCenter
                                            renderType: Text.NativeRendering
                                        }

                                        Item { Layout.fillWidth: true; height: 1 }

                                        Text {
                                            property var appRef: parent.parent.parent
                                            text: appRef.appMuted ? "Unmute" : "Mute"
                                            color: Theme.primary
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 8
                                            Layout.alignment: Qt.AlignVCenter
                                            renderType: Text.NativeRendering

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                hoverEnabled: true
                                                onClicked: root.toggleAppMute(parent.appRef.appIndex)
                                            }
                                        }
                                    }

                                Item {
                                    width: parent.width
                                    height: 8

                                    Row {
                                        property double currentVal: parent.parent.parent.appMuted ? 0 : Math.min(1, parent.parent.parent.appVol / 100)

                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 5
                                        spacing: 1

                                    Repeater {
                                        model: 15
                                        delegate: Rectangle {
                                            height: parent.height
                                            width: (parent.parent.width - (parent.parent.spacing * 14)) / 15
                                            radius: 0
                                            color: index < Math.round(parent.parent.currentVal * 15) ? Theme.primary : Theme.surface
                                        }
                                    }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        preventStealing: true
                                        onPressed: root.setAppVol(parent.parent.parent.appIndex, mouse.x / width)
                                        onPositionChanged: if (pressed) root.setAppVol(parent.parent.parent.appIndex, mouse.x / width)
                                    }

                                    WheelHandler {
                                        acceptedDevices: PointerDevice.Mouse
                                        onWheel: function(event) {
                                            var delta = event.angleDelta.y / 120
                                            var cur = parent.parent.parent.appMuted ? 0 : Math.min(1, parent.parent.parent.appVol / 100)
                                            var newVol = Math.max(0, Math.min(1, cur + delta * 0.05))
                                            root.setAppVol(parent.parent.parent.appIndex, newVol)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Diagnostics ──
                    Column {
                        width: parent.width
                        spacing: 4
                        visible: root.diagnostics ? !!(root.diagnostics.pipewire_version || root.diagnostics.sample_rate) : false

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.primary
                            opacity: 0.25
                        }

                        Text {
                            text: "󰻀 Diagnostics"
                            color: Theme.primary
                            opacity: 0.5
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.bold: true
                            renderType: Text.NativeRendering
                        }

                        Row {
                            width: parent.width
                            spacing: 6

                            Text {
                                text: "PW: " + (root.diagnostics.pipewire_version || "?")
                                color: Theme.primary
                                opacity: 0.6
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                renderType: Text.NativeRendering
                            }

                            Text {
                                text: "SR: " + (root.diagnostics.sample_rate || "?")
                                color: Theme.primary
                                opacity: 0.6
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                renderType: Text.NativeRendering
                            }

                            Text {
                                text: root.diagnostics.output_desc || ""
                                color: Theme.primary
                                opacity: 0.4
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                elide: Text.ElideRight
                                renderType: Text.NativeRendering
                                visible: root.diagnostics ? !!root.diagnostics.output_desc : false
                            }
                        }
                    }

                // ── Bluetooth Media Controls ──
                    Column {
                        width: parent.width
                        spacing: 6
                        visible: root.isBtSink && root.hasPlayer

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.primary
                            opacity: 0.25
                        }

                        Text {
                            text: "󰂯 Bluetooth Controls"
                            color: Theme.primary
                            opacity: 0.5
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.bold: true
                            renderType: Text.NativeRendering
                        }

                        Row {
                            width: parent.width
                            spacing: 20

                            Text {
                                text: "󰙣 Prev"
                                color: Theme.primary
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                anchors.verticalCenter: parent.verticalCenter
                                renderType: Text.NativeRendering

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: root.playerCtl(["previous"])
                                }
                            }

                            Text {
                                text: "󰐊 " + (root.playerStatus === "Playing" ? "Pause" : "Play")
                                color: Theme.primary
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                                renderType: Text.NativeRendering

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: root.playerCtl(["play-pause"])
                                }
                            }

                            Text {
                                text: "󰙡 Next"
                                color: Theme.primary
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                anchors.verticalCenter: parent.verticalCenter
                                renderType: Text.NativeRendering

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: root.playerCtl(["next"])
                                }
                            }
                        }
                    }

            }
        }
    }
}
