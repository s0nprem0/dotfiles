import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../service"

Item {
    id: root

    property bool showPopup: false

    // ── State ──────────────────────────────────────────────────────────
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

    onShowPopupChanged: {
        if (showPopup) refresh()
    }

    function syncFrom(module) {
        root.playerName = module.playerName
        root.playerStatus = module.playerStatus
        root.artist = module.artist
        root.title = module.title
        root.album = module.album
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
        if (!seconds || seconds < 0) return "0:00"
        var m = Math.floor(seconds / 60)
        var s = Math.floor(seconds % 60)
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    // ── Download remote art to local cache ─────────────────────────────
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

    // ── Auto-refresh while open ────────────────────────────────────────
    Timer {
        id: refreshTimer
        interval: 2000
        repeat: true
        running: root.showPopup && root.hasPlayer
        onTriggered: fetchMetadata()
    }

    // ── Combined metadata/status fetch ─────────────────────────────────
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

    // ── Volume fetch (may fail on older playerctl; defaults to 0) ────
    Process {
        id: volProc
        running: false
        stdout: StdioCollector {}
        onExited: {
            root.volume = parseFloat(stdout.text.trim()) || 0
        }
    }

    // ── Position fetch (may fail on older playerctl; defaults to 0) ──
    Process {
        id: posProc
        running: false
        stdout: StdioCollector {}
        onExited: {
            root.position = parseFloat(stdout.text.trim()) || 0
        }
    }

    // ── List players ───────────────────────────────────────────────────
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

    // ── Art cache download ─────────────────────────────────────────────
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

    // ── Player control process ─────────────────────────────────────────
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

    // ══════════════════════════════════════════════════════════════════
    // Per-screen windows via Variants
    // ══════════════════════════════════════════════════════════════════
    Variants {
        model: Quickshell.screens
        delegate: Component {
            PanelWindow {
                id: win
                required property var modelData
                visible: false

                property bool isClosing: false
                property real animRightMargin: -340
                property real animOpacity: 0
                property bool showPopup: root.showPopup

                onShowPopupChanged: {
                    if (root.showPopup) {
                        exitAnim.stop()
                        isClosing = false
                        animRightMargin = -340
                        animOpacity = 0
                        root.refresh()
                        win.visible = true
                        introAnim.start()
                    } else if (!isClosing) {
                        introAnim.stop()
                        closePopup()
                    }
                }

                function closePopup() {
                    if (isClosing) return
                    isClosing = true
                    exitAnim.start()
                }

                screen: modelData
                color: "transparent"
                exclusionMode: PanelWindow.ExclusionMode.Ignore
                focusable: true
                implicitWidth: 340
                implicitHeight: mainColumn.implicitHeight + 20

                anchors {
                    top: true
                    right: true
                }

                margins {
                    top: 40
                    right: win.animRightMargin
                }

                ParallelAnimation {
                    id: introAnim
                    NumberAnimation { target: win; property: "animRightMargin"; from: -340; to: 32; duration: 120; easing.type: Easing.OutCubic }
                    NumberAnimation { target: win; property: "animOpacity"; from: 0; to: 1; duration: 120; easing.type: Easing.OutCubic }
                }

                ParallelAnimation {
                    id: exitAnim
                    onStopped: {
                        win.visible = false
                        root.showPopup = false
                    }
                    NumberAnimation { target: win; property: "animRightMargin"; from: 32; to: -340; duration: 100; easing.type: Easing.InCubic }
                    NumberAnimation { target: win; property: "animOpacity"; from: 1; to: 0; duration: 100; easing.type: Easing.InCubic }
                }

                Rectangle {
                    anchors.fill: parent
                    opacity: win.animOpacity
                    color: Theme.bg
                    border.width: 1
                    border.color: Theme.primary
                    radius: 0
                    focus: true

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) {
                            win.closePopup()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Space) {
                            if (root.hasPlayer) root.playerCtl(["play-pause"])
                            event.accepted = true
                        } else if (event.key === Qt.Key_Left) {
                            if (root.hasPlayer) root.playerCtl(["previous"])
                            event.accepted = true
                        } else if (event.key === Qt.Key_Right) {
                            if (root.hasPlayer) root.playerCtl(["next"])
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
                            if (root.hasPlayer) root.playerCtl(["volume", (root.volume + 0.05).toFixed(2)])
                            event.accepted = true
                        } else if (event.key === Qt.Key_Down) {
                            if (root.hasPlayer) root.playerCtl(["volume", (root.volume - 0.05).toFixed(2)])
                            event.accepted = true
                        }
                    }

                    Column {
                        id: mainColumn
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 10
                        spacing: 8

                        // ── Section 1: Header ─────────────────────────
                        RowLayout {
                            width: parent.width
                            spacing: 4

                            Text {
                                text: "  Now Playing"
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.bold: true
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: "✕"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 13

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: win.closePopup()
                                }
                            }
                        }

                        // ── No Player State ───────────────────────────
                        Text {
                            width: parent.width
                            visible: !root.hasPlayer
                            text: "No media players detected"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter
                        }

                        // ── Player Selector ───────────────────────────
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
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                }

                                Repeater {
                                    model: root.availablePlayers
                                    delegate: Rectangle {
                                        id: playerBtn
                                        required property string modelData
                                        height: 20
                                        width: playerLabel.implicitWidth + 12
                                        radius: 4
                                        color: modelData === root.playerName ? Qt.alpha(Theme.primary, 0.25)
                                             : playerBtnMa.containsMouse ? Qt.alpha(Theme.primary, 0.1)
                                             : "transparent"
                                        border.width: modelData === root.playerName ? 1
                                             : playerBtnMa.containsMouse ? 1
                                             : 0
                                        border.color: playerBtnMa.containsMouse ? Qt.alpha(Theme.primary, 0.4) : Qt.alpha(Theme.primary, 0.3)

                                        Text {
                                            id: playerLabel
                                            anchors.centerIn: parent
                                            text: modelData
                                            color: modelData === root.playerName ? Theme.fg
                                                 : playerBtnMa.containsMouse ? Theme.fg
                                                 : Theme.muted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
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

                        // ── Section 2: Album Art + Track Info ─────────
                        Row {
                            visible: root.hasPlayer
                            width: parent.width
                            spacing: 10

                            Rectangle {
                                id: artFrame
                                width: 96
                                height: 96
                                radius: 6
                                color: Theme.surface
                                border.width: 1
                                border.color: Qt.alpha(Theme.primary, 0.15)
                                clip: true

                                Image {
                                    id: artImage
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectCrop
                                    source: root.artUrl || ""
                                    asynchronous: true
                                    cache: true
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: Theme.surface
                                    visible: root.artUrl && artImage.status === Image.Loading
                                    Text {
                                        anchors.centerIn: parent
                                        text: "…"
                                        color: Theme.muted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 28
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: Theme.surface
                                    visible: !root.artUrl || artImage.status === Image.Error
                                    Text {
                                        anchors.centerIn: parent
                                        text: ""
                                        color: Theme.muted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 36
                                    }
                                }
                            }

                            Column {
                                anchors.verticalCenter: artFrame.verticalCenter
                                width: parent.width - artFrame.width - 10
                                spacing: 3

                                Text {
                                    text: root.title || "No Track"
                                    width: parent.width
                                    color: Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: root.artist || "Unknown Artist"
                                    width: parent.width
                                    color: Qt.alpha(Theme.fg, 0.7)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: root.album || ""
                                    width: parent.width
                                    visible: text.length > 0
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }

                                Item { width: 1; height: 4 }

                                Rectangle {
                                    width: statusLabel.implicitWidth + 8
                                    height: 16
                                    radius: 3
                                    color: root.playerStatus === "Playing" ? Qt.alpha(Theme.green, 0.15)
                                         : root.playerStatus === "Paused" ? Qt.alpha(Theme.warning, 0.15)
                                         : Qt.alpha(Theme.muted, 0.15)

                                    Text {
                                        id: statusLabel
                                        anchors.centerIn: parent
                                        text: root.playerStatus || "Stopped"
                                        color: root.playerStatus === "Playing" ? Theme.green
                                             : root.playerStatus === "Paused" ? Theme.warning
                                             : Theme.muted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        font.bold: true
                                    }
                                }
                            }
                        }

                        // ── Section 3: Controls ───────────────────────
                        Row {
                            visible: root.hasPlayer
                            width: parent.width
                            spacing: 8
                            anchors.horizontalCenter: parent.horizontalCenter

                            Rectangle {
                                width: 28; height: 28; radius: 6
                                color: shuffleBtn.containsMouse ? Qt.alpha(Theme.primary, 0.2) : "transparent"
                                border.width: 1
                                border.color: shuffleBtn.containsMouse ? Qt.alpha(Theme.primary, 0.4) : Qt.alpha(Theme.primary, 0.1)

                                Text {
                                    anchors.centerIn: parent
                                    text: "🔀"
                                    color: Theme.fg
                                    font.pixelSize: 12
                                }

                                MouseArea {
                                    id: shuffleBtn
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.playerCtl(["shuffle", "toggle"])
                                }
                            }

                            Rectangle {
                                width: 36; height: 30; radius: 6
                                color: prevBtn.containsMouse ? Qt.alpha(Theme.primary, 0.2) : "transparent"
                                border.width: 1
                                border.color: prevBtn.containsMouse ? Qt.alpha(Theme.primary, 0.4) : Qt.alpha(Theme.primary, 0.1)

                                Text {
                                    anchors.centerIn: parent
                                    text: "⏮"
                                    color: Theme.fg
                                    font.pixelSize: 14
                                }

                                MouseArea {
                                    id: prevBtn
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.playerCtl(["previous"])
                                }
                            }

                            Rectangle {
                                width: 44; height: 34; radius: 8
                                color: playBtn.containsMouse ? Qt.alpha(Theme.primary, 0.3) : Qt.alpha(Theme.surface, 0.6)
                                border.width: 1
                                border.color: playBtn.containsMouse ? Qt.alpha(Theme.primary, 0.5) : Qt.alpha(Theme.primary, 0.2)

                                Text {
                                    anchors.centerIn: parent
                                    text: root.playerStatus === "Playing" ? "⏸" : "▶"
                                    color: Theme.fg
                                    font.pixelSize: 16
                                }

                                MouseArea {
                                    id: playBtn
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.playerCtl(["play-pause"])
                                }
                            }

                            Rectangle {
                                width: 36; height: 30; radius: 6
                                color: stopBtn.containsMouse ? Qt.alpha(Theme.primary, 0.2) : "transparent"
                                border.width: 1
                                border.color: stopBtn.containsMouse ? Qt.alpha(Theme.primary, 0.4) : Qt.alpha(Theme.primary, 0.1)

                                Text {
                                    anchors.centerIn: parent
                                    text: "⏹"
                                    color: Theme.fg
                                    font.pixelSize: 14
                                }

                                MouseArea {
                                    id: stopBtn
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.playerCtl(["stop"])
                                }
                            }

                            Rectangle {
                                width: 36; height: 30; radius: 6
                                color: nextBtn.containsMouse ? Qt.alpha(Theme.primary, 0.2) : "transparent"
                                border.width: 1
                                border.color: nextBtn.containsMouse ? Qt.alpha(Theme.primary, 0.4) : Qt.alpha(Theme.primary, 0.1)

                                Text {
                                    anchors.centerIn: parent
                                    text: "⏭"
                                    color: Theme.fg
                                    font.pixelSize: 14
                                }

                                MouseArea {
                                    id: nextBtn
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.playerCtl(["next"])
                                }
                            }

                            Rectangle {
                                width: 28; height: 28; radius: 6
                                color: repeatBtn.containsMouse ? Qt.alpha(Theme.primary, 0.2) : "transparent"
                                border.width: 1
                                border.color: repeatBtn.containsMouse ? Qt.alpha(Theme.primary, 0.4) : Qt.alpha(Theme.primary, 0.1)

                                Text {
                                    anchors.centerIn: parent
                                    text: "🔁"
                                    color: Theme.fg
                                    font.pixelSize: 12
                                }

                                MouseArea {
                                    id: repeatBtn
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.playerCtl(["repeat", "toggle"])
                                }
                            }
                        }

                        // ── Section 4: Seek Bar ───────────────────────
                        Row {
                            visible: root.hasPlayer && root.trackLength > 0
                            width: parent.width
                            spacing: 4

                            Text {
                                text: root.formatTime(root.position)
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                anchors.verticalCenter: parent.verticalCenter
                                width: 32
                            }

                            Rectangle {
                                id: seekBg
                                width: parent.width - 72
                                height: 6
                                radius: 3
                                color: Theme.surface
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    width: Math.min(seekBg.width, seekBg.width * (root.position / (root.trackLength / 1000000)))
                                    height: parent.height
                                    radius: 3
                                    color: Theme.primary
                                }

                                Rectangle {
                                    x: Math.min(seekBg.width - 4, seekBg.width * (root.position / (root.trackLength / 1000000)) - 2)
                                    y: (parent.height - 8) / 2
                                    width: 8; height: 8; radius: 4
                                    color: Theme.fg
                                    visible: root.position > 0
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
                                text: root.formatTime(root.trackLength / 1000000)
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                anchors.verticalCenter: parent.verticalCenter
                                width: 32
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        // ── Section 5: Volume ─────────────────────────
                        Row {
                            visible: root.hasPlayer
                            width: parent.width
                            spacing: 6

                            Text {
                                text: ""
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Rectangle {
                                id: volBarBg
                                width: parent.width - 30
                                height: 6
                                radius: 3
                                color: Theme.surface
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    width: volBarBg.width * root.volume
                                    height: parent.height
                                    radius: 3
                                    color: Theme.primary
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var frac = mouse.x / width
                                        root.playerCtl(["volume", frac.toFixed(2)])
                                    }
                                }
                            }

                            Text {
                                text: Math.round(root.volume * 100) + "%"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                anchors.verticalCenter: parent.verticalCenter
                                width: 36
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }
            }
        }
    }
}
