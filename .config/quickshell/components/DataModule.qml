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
  }

  Timer {
    interval: root.interval
    running: true
    repeat: true
    onTriggered: proc.running = true
  }

  function refresh() {
    proc.running = true
  }

  Component.onCompleted: proc.running = true

  signal dataReceived(var json)
}
