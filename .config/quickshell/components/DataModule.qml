import Quickshell
import Quickshell.Io
import QtQuick

Item {
  id: root
  visible: false

  property string path: ""
  property int interval: 5000

  Process {
    id: proc
    command: [root.path]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.dataReceived(JSON.parse(this.text))
        } catch (e) { console.warn("DataModule JSON parse error:", e) }
      }
    }
    onExited: function(code) {
      if (code !== 0) crashRestart.restart()
    }
  }

  property int backoffMs: 1000

  Timer {
    id: crashRestart
    interval: root.backoffMs
    repeat: false
    onTriggered: {
      root.backoffMs = Math.min(root.backoffMs * 2, 30000)
      if (!proc.running) proc.running = true
    }
  }

  onDataReceived: root.backoffMs = 1000

  Timer {
    interval: root.interval
    running: true
    repeat: true
    onTriggered: { if (!proc.running) proc.running = true }
  }

  function refresh() {
    proc.running = true
  }

  Component.onCompleted: proc.running = true

  signal dataReceived(var json)
}
