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
    onExited: {
      // Restart after short backoff on crash/failure
      crashRestart.restart()
    }
  }

  Timer {
    id: crashRestart
    interval: 1000
    repeat: false
    onTriggered: { proc.running = true }
  }

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
