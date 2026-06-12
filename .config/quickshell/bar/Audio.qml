import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import "../components"
import "../service"

BarModule {
  id: root

  implicitWidth: contentRow.implicitWidth + 12

  property int vol: 0
  property bool isMuted: false
  property var mediaPopupRef: null

  property int micVol: 100
  property bool micMuted: false

  property string playerName: ""
  property string playerStatus: ""
  property string artist: ""
  property string title: ""
  property string artUrl: ""
  property double trackLength: 0
  property bool hasPlayer: false

  // Event-driven audio monitoring via pactl subscribe
  // Falls back to polling every 30s in case events are missed
  DataModule {
    id: audioData
    path: Theme.bin("get_audio_status")
    interval: 30000
    onDataReceived: function(j) {
      root.vol = j.default_sink ? (j.default_sink.volume ?? 0) : (j.volume ?? 0)
      root.isMuted = j.default_sink ? (j.default_sink.muted ?? false) : (j.muted ?? false)
      if (j.default_source) {
        root.micVol = j.default_source.volume ?? 100
        root.micMuted = j.default_source.muted ?? false
      }
      if (root.mediaPopupRef && root.mediaPopupRef.showPopup) {
        root.mediaPopupRef.sysVol = root.vol
        root.mediaPopupRef.sysMuted = root.isMuted
        root.mediaPopupRef.micVol = root.micVol
        root.mediaPopupRef.micMuted = root.micMuted
      }
    }
  }
  Binding { target: root; property: "error"; value: audioData.hasError }
  Binding { target: root; property: "loading"; value: audioData.loading }

  Process {
    id: pactlSub
    command: ["pactl", "subscribe"]
    running: true
    stdout: SplitParser {
      onRead: function(data) {
        var line = data.trim()
        // pactl subscribe outputs lines like "Event 'change' on sink #43"
        if (line.includes("'change'")) audioDebounce.restart()
      }
    }
  }

  Timer {
    id: audioDebounce
    interval: 200
    onTriggered: audioData.refresh()
  }

  FileView {
    path: Theme.home + "/.cache/quickshell/osd_state.json"
    onDataChanged: audioDebounce.restart()
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

  function fetchPlayerInfo() {
    if (!root.playerName) return
    if (playerFollowProc.running) {
      playerFollowProc.running = false
      restartFollow.restart()
    } else {
      doStartFollow()
    }
  }

  function doStartFollow() {
    playerFollowProc.command = [
      "playerctl", "-p", root.playerName, "--follow",
      "--format", "{{artist}}|{{title}}|{{mpris:artUrl}}|{{mpris:length}}|{{mpris:playback-status}}"
    ]
    playerFollowProc.running = true
  }

  Timer {
    id: restartFollow
    interval: 50
    onTriggered: doStartFollow()
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
        fetchPlayerInfo()
      } else {
        root.hasPlayer = false
      }
    }
  }

  Process {
    id: playerFollowProc
    running: false
    stdout: SplitParser {
      onRead: function(data) {
        var parts = data.trim().split("|")
        if (parts.length >= 4) {
          root.artist = parts[0] || ""
          root.title = parts[1] || ""
          root.artUrl = parts[2] || ""
          var len = parseInt(parts[3])
          root.trackLength = isNaN(len) ? 0 : len
        }
        if (parts.length >= 5) {
          root.playerStatus = parts[4] || ""
        }
      }
    }
    onExited: {
      root.playerName = ""
      root.hasPlayer = false
    }
  }

  Process { id: audioAction }
  Process { id: audioGui }

  Timer {
    id: wheelDebounce
    interval: 150
    onTriggered: {
      audioAction.command = wheelDebounce.privCommand
      audioAction.running = true
    }
    property var privCommand: []
  }

  acceptedButtons: Qt.LeftButton | Qt.RightButton

  Connections {
    target: mA
    function onClicked(mouse) {
      if (mouse.button === Qt.RightButton) {
        if (root.hasPlayer) {
          Quickshell.execDetached(["playerctl", "-p", root.playerName, "play-pause"])
        } else {
          audioGui.command = ["pavucontrol"]
          audioGui.running = true
        }
      } else if (root.mediaPopupRef) {
        root.mediaPopupRef.sysVol = root.vol
        root.mediaPopupRef.sysMuted = root.isMuted
        root.mediaPopupRef.micVol = root.micVol
        root.mediaPopupRef.micMuted = root.micMuted
        root.mediaPopupRef.showPopup = !root.mediaPopupRef.showPopup
      }
    }
  }

  WheelHandler {
    acceptedDevices: PointerDevice.Mouse
    onWheel: event => {
      wheelDebounce.stop()
      wheelDebounce.privCommand = event.angleDelta.y > 0
        ? [Theme.bin("osdctl"), "volume", "up"]
        : [Theme.bin("osdctl"), "volume", "down"]
      wheelDebounce.start()
    }
  }

  Connections {
    target: audioAction
    function onRunningChanged() {
      if (!audioAction.running) audioData.refresh()
    }
  }

  tooltipText: root.hasPlayer
    ? (root.artist ? root.artist + " - " + root.title : root.title || root.playerName)
    : root.isMuted ? "Muted" : root.vol + "%"

  RowLayout {
    id: contentRow
    anchors.centerIn: parent
    spacing: 3

    Text {
      text: root.isMuted ? "󰝟" : (root.vol > 70 ? "󰕾" : root.vol > 30 ? "󰖀" : "󰕿")
      color: root.isMuted ? Theme.muted : Theme.fg
      font.family: Theme.fontFamily
      font.pixelSize: 11
    }

    Text {
      id: audioLabel
      text: root.isMuted ? "Muted" : root.vol + "%"
      color: root.isMuted ? Theme.muted : Qt.alpha(Theme.fg, 0.7)
      font.family: Theme.fontFamily
      font.pixelSize: 11
    }
  }
}
