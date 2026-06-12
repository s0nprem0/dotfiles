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
    id: pollTimer
    interval: 3000
    repeat: true
    running: root.hasPlayer
    onTriggered: fetchPlayerInfo()
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
    metaProc.command = ["playerctl", "-p", root.playerName, "metadata", "--format", "{{artist}}|{{title}}|{{mpris:artUrl}}|{{mpris:length}}"]
    metaProc.running = true
    statusProc.running = true
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
    id: metaProc
    running: false
    stdout: StdioCollector {}
    onExited: {
      var out = stdout.text.trim()
      if (!out) return
      var parts = out.split("|")
      root.artist = parts.length > 0 ? parts[0] : ""
      root.title = parts.length > 1 ? parts[1] : ""
      root.artUrl = parts.length > 2 ? parts[2] : ""
      if (parts.length > 3) {
        var len = parseInt(parts[3])
        root.trackLength = isNaN(len) ? 0 : len
      } else {
        root.trackLength = 0
      }
    }
  }

  Process {
    id: statusProc
    running: false
    stdout: StdioCollector {}
    onExited: {
      var s = stdout.text.trim()
      if (s === "Playing" || s === "Paused") {
        root.playerStatus = s
      } else {
        root.hasPlayer = false
      }
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
        ? ["wpctl", "set-volume", "-l", "1.5", "@DEFAULT_AUDIO_SINK@", "5%+"]
        : ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%-"]
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
