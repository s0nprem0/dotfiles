import Quickshell
import Quickshell.Io
import QtQuick

Item {
  id: root
  visible: false

  property string path: ""
  property int interval: 5000
  property bool hasError: false
  property bool loading: false

  Process {
    id: proc
    command: [root.path]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.loading = false
          root.dataReceived(JSON.parse(this.text))
        } catch (e) {
          root.hasError = true
          root.loading = false
          console.warn("DataModule JSON parse error:", e)
        }
      }
    }
    onRunningChanged: {
      if (proc.running) { root.loading = true; root.hasError = false; root.backoffMs = 1000 }
    }
    onExited: function(code) {
      root.loading = false
      if (code !== 0) {
        root.hasError = true
        crashRestart.restart()
      }
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
