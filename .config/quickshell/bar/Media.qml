import Quickshell
import Quickshell.Io
import QtQuick

import "../components"
import "../service"

BarModule {
    id: root

    implicitWidth: 32

    property string playerName: ""
    property string playerStatus: ""
    property string artist: ""
    property string title: ""
    property string album: ""
    property bool hasPlayer: false
    property var mediaPopupRef: null

    Timer {
        id: pollTimer
        interval: 3000
        repeat: true
        running: root.hasPlayer
        onTriggered: fetchMetadata()
    }

    Timer {
        id: checkTimer
        interval: 10000
        repeat: true
        running: !root.hasPlayer
        triggeredOnStart: true
        onTriggered: playerListProc.running = true
    }

    function refresh() {
        playerListProc.running = true
    }

    Process {
        id: playerListProc
        command: ["playerctl", "-l"]
        running: false
        stdout: StdioCollector {}
        onExited: {
            var out = stdout.text.trim()
            if (!out) {
                root.hasPlayer = false
                return
            }
            var list = out.split("\n")
            var p = list.length > 0 ? list[0].trim() : ""
            if (p) {
                root.hasPlayer = true
                root.playerName = p
                fetchMetadata()
            } else {
                root.hasPlayer = false
            }
        }
    }

    function fetchMetadata() {
        if (!root.playerName) return
        metaProc.command = ["playerctl", "-p", root.playerName, "metadata", "--format", "{{artist}}|{{title}}|{{album}}|{{mpris:artUrl}}"]
        metaProc.running = true
        statusProc.command = ["playerctl", "-p", root.playerName, "status"]
        statusProc.running = true
    }

    Process {
        id: metaProc
        running: false
        stdout: StdioCollector {}
        onExited: {
            var out = stdout.text.trim()
            if (!out) {
                root.hasPlayer = false
                return
            }
            var parts = out.split("|")
            root.artist = parts.length > 0 ? parts[0] : ""
            root.title = parts.length > 1 ? parts[1] : ""
            root.album = parts.length > 2 ? parts[2] : ""
        }
    }

    Process {
        id: statusProc
        running: false
        stdout: StdioCollector {}
        onExited: {
            root.playerStatus = stdout.text.trim()
        }
    }

    acceptedButtons: Qt.LeftButton | Qt.RightButton

    Connections {
        target: mA
        function onClicked(mouse) {
            if (mouse.button === Qt.LeftButton) {
                if (root.mediaPopupRef) {
                    root.mediaPopupRef.syncFrom(root)
                    root.mediaPopupRef.showPopup = !root.mediaPopupRef.showPopup
                }
            } else if (mouse.button === Qt.RightButton && root.hasPlayer) {
                Quickshell.execDetached(["playerctl", "-p", root.playerName, "play-pause"])
            }
        }
    }

    tooltipText: root.hasPlayer
        ? (root.artist ? root.artist + " - " + root.title : root.title || root.playerName)
        : ""

    Text {
        anchors.centerIn: parent
        text: root.hasPlayer ? "" : ""
        color: root.playerStatus === "Playing" ? Theme.green
             : root.playerStatus === "Paused" ? Qt.alpha(Theme.fg, 0.5)
             : Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }
}
