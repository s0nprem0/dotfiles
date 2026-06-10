import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../service"

PopupPanel {
    id: root

    // ── Configuration ──
    anchorSide: "right"
    panelWidth: 340
    panelMaxHeight: 0
    initialOffset: -340
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

    onBeforeOpen: { refresh(); refreshSinks() }

    Component.onCompleted: refreshSinks()

    function syncFrom(module) {
        root.playerName = module.playerName
        root.playerStatus = module.playerStatus
        root.artist = module.artist
        root.title = module.title
        root.album = module.album
        root.artUrl = module.artUrl || ""
        root.trackLength = module.trackLength || 0
        root.volume = module.volume || 0
        root.position = module.position || 0
        root.hasPlayer = module.hasPlayer
    }

    function refresh() {
        listPlayersProc.running = true
    }

    function fetchMetadata() {
        if (!root.playerName) return
        fetchProc.command = ["sh", "-c",
            "p=\"$1\"\n" +
            "playerctl -p \"$p\" metadata --format '{{artist}}|{{title}}|{{album}}|{{mpris:artUrl}}|{{mpris:length}}' 2>/dev/null\n" +
            "echo \"---\"\n" +
            "playerctl -p \"$p\" status 2>/dev/null",
            "_", root.playerName]
        fetchProc.running = true
        volProc.command = ["playerctl", "-p", root.playerName, "volume"]
        volProc.running = true
        posProc.command = ["playerctl", "-p", root.playerName, "position"]
        posProc.running = true
    }

    function formatTime(seconds) {
        if (typeof seconds !== "number" || seconds < 0) return "0:00"
        var m = Math.floor(seconds / 60)
        var s = Math.floor(seconds % 60)
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    function ensureArtCache(url) {
        if (!url || url.indexOf("://") === -1) return
        if (url.indexOf("file://") === 0) return
        artCacheProc.command = ["sh", "-c",
            "url=\"$1\"\n" +
            "hash=$(echo \"$url\" | md5sum | cut -c1-16)\n" +
            "path=\"/tmp/media_art_$hash\"\n" +
            "find /tmp/media_art_* -mmin +60 -delete 2>/dev/null\n" +
            "[ -f \"$path\" ] || curl -sL -o \"$path\" \"$url\"\n" +
            "echo \"$path\"",
            "_", url]
        artCacheProc.running = true
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

    // ── Volume batch timer: applies pending changes every 50ms ──
    Timer {
        id: volumeApplyTimer
        interval: 50
        repeat: true
        running: root.pendingOutVol !== -1 || root.pendingInVol !== -1 || Object.keys(root.pendingAppVols).length > 0
        onTriggered: {
            if (root.pendingOutVol !== -1) {
                var pct = Math.round(root.pendingOutVol * 100)
                sysVolAction.command = ["wpctl", "set-volume", "-l", "1.5", "@DEFAULT_AUDIO_SINK@", pct + "%"]
                sysVolAction.running = true
                if (root.audioBarRef) {
                    root.audioBarRef.vol = Math.round(root.pendingOutVol * 100)
                    root.audioBarRef.isMuted = false
                }
                refreshSinks()
                root.pendingOutVol = -1
            }
            if (root.pendingInVol !== -1) {
                var pct2 = Math.round(root.pendingInVol * 100)
                micVolAction.command = ["wpctl", "set-volume", "-l", "1.5", "@DEFAULT_AUDIO_SOURCE@", pct2 + "%"]
                micVolAction.running = true
                refreshSinks()
                root.pendingInVol = -1
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
                refreshSinks()
            }
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

    // ── Audio Sinks (devices) ──
    property var sinkList: []
    property string activeSinkId: ""

    Process {
        id: listSinksProc
        command: ["sh", "-c",
            "echo \"DEFAULT:$(pactl get-default-sink 2>/dev/null)\" && " +
            "pactl list sinks | grep -E \"Sink #|Description:|Name:\" | sed 's/^[[:space:]]*//'"]
        running: false
        stdout: StdioCollector {}
        onExited: {
            var out = stdout.text.trim()
            if (!out) return
            var lines = out.split("\n")
            var defaultSink = ""
            var newList = []
            var newActive = root.activeSinkId

            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim()
                if (!line) continue

                // First line: DEFAULT:<name>
                if (line.indexOf("DEFAULT:") === 0) {
                    defaultSink = line.substring(8).trim()
                    continue
                }

                // Group 3 lines per sink: Sink #, Name:, Description:
                if (line.indexOf("Sink #") === 0) {
                    var sinkId = line.replace(/.*#/, "").replace(/:$/, "").trim()
                    var sinkName = ""
                    var sinkDesc = ""

                    // Next line: Name:
                    if (i + 1 < lines.length) {
                        var nameLine = lines[i + 1].trim()
                        if (nameLine.indexOf("Name:") === 0) {
                            sinkName = nameLine.substring(5).trim()
                        }
                    }
                    // Next next line: Description:
                    if (i + 2 < lines.length) {
                        var descLine = lines[i + 2].trim()
                        if (descLine.indexOf("Description:") === 0) {
                            sinkDesc = descLine.substring(12).trim()
                        }
                    }

                    var displayName = sinkDesc || sinkName || ("Sink " + sinkId)
                    var isActive = sinkName === defaultSink
                    newList.push(sinkId + "||" + displayName)
                    if (isActive) newActive = sinkId
                    i += 2
                }
            }

            root.sinkList = newList
            root.activeSinkId = newActive || (newList.length > 0 ? newList[0].split("||")[0].trim() : "")
            root.isBtSink = defaultSink.toLowerCase().indexOf("bluez") >= 0
            refreshApps()
        }
    }

    Process {
        id: setSinkProc
        running: false
    }

    function refreshSinks() {
        listSinksProc.running = true
        listSourcesProc.running = true
    }

    function refreshSources() {
        listSourcesProc.running = true
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

    // ── Audio Sources (input devices) ──
    property var sourceList: []
    property string activeSourceId: ""

    Process {
        id: listSourcesProc
        command: ["sh", "-c",
            "echo \"DEFAULT:$(pactl get-default-source 2>/dev/null)\" && " +
            "pactl list sources | grep -E \"Source #|Description:|Name:\" | sed 's/^[[:space:]]*//'"]
        running: false
        stdout: StdioCollector {}
        onExited: {
            var out = stdout.text.trim()
            if (!out) return
            var lines = out.split("\n")
            var defaultSource = ""
            var newList = []
            var newActive = root.activeSourceId

            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim()
                if (!line) continue

                if (line.indexOf("DEFAULT:") === 0) {
                    defaultSource = line.substring(8).trim()
                    continue
                }

                if (line.indexOf("Source #") === 0) {
                    var srcId = line.replace(/.*#/, "").replace(/:$/, "").trim()
                    var srcName = ""
                    var srcDesc = ""

                    if (i + 1 < lines.length) {
                        var nameLine = lines[i + 1].trim()
                        if (nameLine.indexOf("Name:") === 0)
                            srcName = nameLine.substring(5).trim()
                    }
                    if (i + 2 < lines.length) {
                        var descLine = lines[i + 2].trim()
                        if (descLine.indexOf("Description:") === 0)
                            srcDesc = descLine.substring(12).trim()
                    }

                    var displayName = srcDesc || srcName || ("Source " + srcId)
                    var isActive = srcName === defaultSource
                    newList.push(srcId + "||" + displayName)
                    if (isActive) newActive = srcId
                    i += 2
                }
            }

            root.sourceList = newList
            root.activeSourceId = newActive || (newList.length > 0 ? newList[0].split("||")[0].trim() : "")
        }
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
        onTriggered: { fetchMetadata(); refreshSinks() }
    }

    Timer {
        id: sinkRefreshTimer
        interval: 4000
        repeat: true
        running: root.showPopup && !root.hasPlayer
        onTriggered: refreshSinks()
    }

    // ── pactl subscribe for real-time updates ──
    Process {
        id: pactlSubscribe
        command: ["pactl", "subscribe"]
        running: true
        stdout: SplitParser {
            onRead: function(data) { subDebounce.restart() }
        }
    }

    Timer {
        id: subDebounce
        interval: 200
        onTriggered: { refreshSinks(); refreshApps() }
    }

    // ── App Volumes ──
    property var appList: []

    Process {
        id: listAppsProc
        command: ["pactl", "-f", "json", "list", "sink-inputs"]
        running: false
        stdout: StdioCollector {}
        onExited: {
            var out = stdout.text.trim()
            if (!out) { root.appList = []; return }
            try {
                var data = JSON.parse(out)
                var newList = []
                for (var i = 0; i < data.length; i++) {
                    var app = data[i]
                    var props = app.properties || {}
                    var name = props["application.name"] || "Unknown"
                    var volObj = app.volume || {}
                    var volKeys = Object.keys(volObj)
                    var vol = 0
                    if (volKeys.length > 0) {
                        var firstVol = volObj[volKeys[0]]
                        var pctStr = (firstVol ? firstVol["value_percent"] : null) || "0%"
                        vol = parseInt(pctStr) || 0
                    }
                    var muted = app.mute || false
                    newList.push(app.index + "||" + name + "||" + vol + "||" + muted)
                }
                root.appList = newList
            } catch (e) { root.appList = [] }
        }
    }

    Process { id: setAppVolProc }
    Process { id: setAppMuteProc }

    function refreshApps() {
        listAppsProc.running = true
    }

    function setAppVol(id, frac) {
        frac = Math.max(0, Math.min(1, frac))
        root.pendingAppVols[String(id)] = frac
    }

    function toggleAppMute(id) {
        setAppMuteProc.command = ["pactl", "set-sink-input-mute", String(id), "toggle"]
        setAppMuteProc.running = true
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
        root.fetchMetadata()
    }

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

    // ── Combined metadata/status fetch ──
    Process {
        id: fetchProc
        running: false
        stdout: StdioCollector {}
        onExited: {
            var out = stdout.text.trim()
            if (!out) return
            var sections = out.split("---")
            if (sections.length >= 1) {
                var meta = (sections[0] || "").trim()
                if (meta) {
                    var fields = meta.split("|")
                    root.artist = fields[0] || ""
                    root.title = fields[1] || ""
                    root.album = fields[2] || ""
                    var newArtUrl = fields[3] || ""
                    root.trackLength = parseFloat(fields[4]) || 0
                    if (newArtUrl !== root.artUrl) {
                        root.artUrl = newArtUrl
                        ensureArtCache(newArtUrl)
                    }
                }
            }
            if (sections.length >= 2) root.playerStatus = (sections[1] || "").trim()
        }
    }

    // ── Volume fetch ──
    Process {
        id: volProc
        running: false
        stdout: StdioCollector {}
        onExited: {
            root.volume = parseFloat(stdout.text.trim()) || 0
        }
    }

    // ── Position fetch ──
    Process {
        id: posProc
        running: false
        stdout: StdioCollector {}
        onExited: {
            root.position = parseFloat(stdout.text.trim()) || 0
        }
    }

    // ── List players ──
    Process {
        id: listPlayersProc
        command: ["playerctl", "-l"]
        running: false
        stdout: StdioCollector {}
        onExited: {
            var out = stdout.text.trim()
            if (!out) {
                root.hasPlayer = false
                root.availablePlayers = []
                return
            }
            var list = out.split("\n").filter(function(s) { return s.trim() !== "" })
            root.availablePlayers = list
            if (list.length > 0) {
                if (!root.playerName || list.indexOf(root.playerName) === -1) {
                    root.playerName = list[0].trim()
                }
                root.hasPlayer = true
                fetchMetadata()
            } else {
                root.hasPlayer = false
            }
        }
    }

    // ── Art cache download ──
    Process {
        id: artCacheProc
        running: false
        stdout: StdioCollector {}
        onExited: {
            var path = stdout.text.trim()
            if (path) {
                root.artUrl = "file://" + path
            }
        }
    }

    // ── Player control process ──
    Process {
        id: ctlProc
        running: false
        onExited: { fetchMetadata() }
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
                                        root.fetchMetadata()
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Media content (animated on source switch) ──
                Item {
                    opacity: root.mediaFade
                    transform: Translate { y: root.mediaSlide }
                    visible: root.hasPlayer
                    width: parent.width
                    implicitHeight: mediaColumn.implicitHeight

                    Column {
                        id: mediaColumn
                        width: parent.width
                        spacing: 6

                    // ── Section 2: Album Art + Track Info ──
                    Row {
                        visible: root.hasPlayer
                        width: parent.width
                        spacing: 8
    
                        Rectangle {
                            id: artFrame
                            width: 48
                            height: 48
                            color: Theme.surface
                            border.width: 1
                            border.color: Theme.primary
                            clip: true
                            radius: 0
    
                            Image {
                                id: artImage
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectCrop
                                source: root.artUrl || ""
                                asynchronous: true
                                cache: true
                            }
    
                            Text {
                                anchors.centerIn: parent
                                text: "󰎆"
                                color: Theme.primary
                                font.family: Theme.fontFamily
                                font.pixelSize: 20
                                visible: !root.artUrl || artImage.status === Image.Error
                                renderType: Text.NativeRendering
                            }
                        }
    
                        Column {
                            width: parent.width - 56
                            anchors.verticalCenter: artFrame.verticalCenter
                            spacing: 1

                            Row {
                                width: parent.width
                                spacing: 6

                                Text {
                                    width: parent.width - sourceIndicatorRow.implicitWidth - 6
                                    text: root.title || "No Track"
                                    color: Theme.primary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.bold: true
                                    elide: Text.ElideRight
                                    renderType: Text.NativeRendering
                                }

                                Row {
                                    id: sourceIndicatorRow
                                    spacing: 3
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: root.availablePlayers.length > 1
                                    height: 8

                                    Repeater {
                                        model: root.availablePlayers
                                        delegate: Rectangle {
                                            width: 5; height: 5
                                            radius: 0
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: modelData === root.playerName ? Theme.primary : Theme.surface
                                            border.width: 1
                                            border.color: Theme.primary
                                            opacity: modelData === root.playerName ? 1 : 0.55
                                        }
                                    }
                                }
                            }

                            Text {
                                text: root.artist ? root.artist + (root.album ? " • " + root.album : "") : (root.playerName || "")
                                width: parent.width
                                color: Theme.primary
                                opacity: 0.6
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                elide: Text.ElideRight
                                renderType: Text.NativeRendering
                            }

                            Row {
                                spacing: 4
                                visible: root.playerStatus

                                Rectangle {
                                    height: 4; width: 4
                                    radius: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: root.playerStatus === "Playing" ? Theme.green
                                         : root.playerStatus === "Paused" ? Theme.warning
                                         : Theme.muted
                                }

                                Text {
                                    text: root.playerStatus || ""
                                    color: root.playerStatus === "Playing" ? Theme.green
                                         : root.playerStatus === "Paused" ? Theme.warning
                                         : Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 8
                                    font.bold: true
                                    renderType: Text.NativeRendering
                                }
                            }
                        }
                    }
    
                    // ── Section 3: Controls ──
                    Row {
                        visible: root.hasPlayer
                        width: parent.width
                        spacing: 12
    
                        Text {
                            id: shuffleLabel
                            text: "󰒝"
                            color: Theme.primary
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                            opacity: 0.5
                            renderType: Text.NativeRendering

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: parent.opacity = 1
                                onExited: parent.opacity = 0.5
                                onClicked: root.playerCtl(["shuffle", "toggle"])
                            }
                        }

                        Text {
                            id: prevLabel
                            text: "prev"
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
                            id: playLabel
                            text: root.playerStatus === "Playing" ? "pause" : "play"
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
                            id: nextLabel
                            text: "next"
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

                        Text {
                            id: stopLabel
                            text: "stop"
                            color: Theme.primary
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            anchors.verticalCenter: parent.verticalCenter
                            opacity: 0.6
                            renderType: Text.NativeRendering

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: root.playerCtl(["stop"])
                            }
                        }

                        Text {
                            id: repeatLabel
                            text: "󰑘"
                            color: Theme.primary
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                            opacity: 0.5
                            renderType: Text.NativeRendering

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: parent.opacity = 1
                                onExited: parent.opacity = 0.5
                                onClicked: root.playerCtl(["repeat", "toggle"])
                            }
                        }

                        Text {
                            id: sourceSwitchLabel
                            text: "󰑖"
                            color: Theme.primary
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.availablePlayers.length > 1
                            opacity: 0.5
                            renderType: Text.NativeRendering

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: parent.opacity = 1
                                onExited: parent.opacity = 0.5
                                onClicked: {
                                    root.switchMediaSource()
                                }
                            }
                        }
    
                    }
    
                    // ── Section 4: Seek Bar ──
                    Row {
                        visible: root.hasPlayer && root.trackLength > 0
                        width: parent.width
                        spacing: 6
                        height: 14

                        Text {
                            id: seekTimeStart
                            text: root.formatTime(root.position)
                            color: Theme.primary
                            opacity: 0.5
                            font.family: Theme.fontFamily
                            font.pixelSize: 8
                            anchors.verticalCenter: parent.verticalCenter
                            renderType: Text.NativeRendering
                        }

                        Item {
                            width: parent.width - seekTimeStart.implicitWidth - seekTimeEnd.implicitWidth - parent.spacing * 2
                            height: parent.height
                            clip: true

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                height: 4
                                color: Theme.surface

                                Rectangle {
                                    width: parent.width * Math.min(1, root.position / (root.trackLength / 1000000))
                                    height: parent.height
                                    color: Theme.primary
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var frac = Math.max(0, Math.min(1, mouse.x / width))
                                    var secs = frac * (root.trackLength / 1000000)
                                    root.playerCtl(["position", secs.toFixed(1)])
                                }
                            }
                        }

                        Text {
                            id: seekTimeEnd
                            text: root.formatTime(root.trackLength / 1000000)
                            color: Theme.primary
                            opacity: 0.5
                            font.family: Theme.fontFamily
                            font.pixelSize: 8
                            anchors.verticalCenter: parent.verticalCenter
                            renderType: Text.NativeRendering
                        }
                    }
    
                    // ── Section 5: Player Volume ──
                    Column {
                        visible: root.hasPlayer
                        width: parent.width
                        spacing: 4

                        Row {
                            width: parent.width

                            Text {
                                text: "󰕾 Volume: " + Math.round(root.volume * 100) + "%"
                                color: Theme.primary
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                                renderType: Text.NativeRendering
                            }

                            Item { width: parent.width - childrenRect.width - mutePlayerText.width; height: 1 }

                            Text {
                                id: mutePlayerText
                                text: root.volume === 0 ? "Unmute" : "Mute"
                                color: Theme.primary
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                anchors.verticalCenter: parent.verticalCenter
                                renderType: Text.NativeRendering

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: root.playerCtl(["volume", root.volume === 0 ? "1.0" : "0.0"])
                                }
                            }
                        }

                        Item {
                            width: parent.width
                            height: 8

                            Row {
                                id: playerVolBlocks
                                property double currentVal: Math.min(1, root.volume)

                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                height: 5
                                spacing: 1

                                Repeater {
                                    model: 15
                                    delegate: Rectangle {
                                        height: parent.height
                                        width: (playerVolBlocks.width - (playerVolBlocks.spacing * 14)) / 15
                                        radius: 0
                                        color: index < Math.round(playerVolBlocks.currentVal * 15) ? Theme.primary : Theme.surface
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                preventStealing: true
                                onPressed: root.playerCtl(["volume", Math.max(0.01, Math.min(1, mouse.x / width)).toFixed(2)])
                                onPositionChanged: if (pressed) root.playerCtl(["volume", Math.max(0.01, Math.min(1, mouse.x / width)).toFixed(2)])
                            }

                            WheelHandler {
                                acceptedDevices: PointerDevice.Mouse
                                onWheel: function(event) {
                                    var delta = event.angleDelta.y / 120
                                    var newVol = Math.max(0, Math.min(1, root.volume + delta * 0.05))
                                    root.playerCtl(["volume", newVol.toFixed(2)])
                                }
                            }
                        }
                    }
                    }
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
                                }
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 8

                        Row {
                            id: sysBlocks
                            property double currentVal: root.sysMuted ? 0 : Math.min(1, root.sysVol / 100)

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: 5
                            spacing: 1

                            Repeater {
                                model: 15
                                delegate: Rectangle {
                                    height: parent.height
                                    width: (sysBlocks.width - (sysBlocks.spacing * 14)) / 15
                                    radius: 0
                                    color: index < Math.round(sysBlocks.currentVal * 15) ? Theme.primary : Theme.surface
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            preventStealing: true
                            onPressed: root.setSysVol(mouse.x / width)
                            onPositionChanged: if (pressed) root.setSysVol(mouse.x / width)
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
