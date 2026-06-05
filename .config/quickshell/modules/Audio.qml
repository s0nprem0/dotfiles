import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import ".."
import "../components"

BarModule {
  id: root

  implicitWidth: contentRow.implicitWidth + 12

  property int vol: 0
  property bool isMuted: false

  DataModule {
    id: audioData
    path: Theme.bin("get_audio_status")
    interval: 1000
    onDataReceived: function(j) {
      root.vol = j.volume
      root.isMuted = j.muted
    }
  }

  Process { id: runner }

  acceptedButtons: Qt.LeftButton | Qt.RightButton

  Connections {
    target: mA
    function onClicked(mouse) {
      if (mouse.button === Qt.RightButton) {
        runner.command = ["pavucontrol"]
        runner.running = true
      } else {
        runner.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
        runner.running = true
      }
    }
    function onWheel(wheel) {
      runner.command = wheel.angleDelta.y > 0
        ? ["wpctl", "set-volume", "-l", "1.5", "@DEFAULT_AUDIO_SINK@", "5%+"]
        : ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%-"]
      runner.running = true
    }
  }

  Connections {
    target: runner
    function onRunningChanged() {
      if (!runner.running) audioData.refresh()
    }
  }

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
