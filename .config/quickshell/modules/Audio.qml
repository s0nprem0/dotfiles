import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import "../Theme.js" as Theme
import "../components"

BarModule {
  id: root

  implicitWidth: audioLabel.x + audioLabel.implicitWidth + 10

  property int vol: 0
  property bool isMuted: false

  DataModule {
    path: Theme.bin("get_audio_status")
    interval: 3000
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
        runner.command = ["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"]
        runner.running = true
      }
    }
    function onWheel(wheel) {
      runner.command = [
        "pactl", "set-sink-volume", "@DEFAULT_SINK@",
        wheel.angleDelta.y > 0 ? "+5%" : "-5%"
      ]
      runner.running = true
    }
  }

  RowLayout {
    anchors.centerIn: parent
    spacing: 3

    Text {
      text: root.isMuted ? "󰝟" : (root.vol > 50 ? "󰕾" : root.vol > 0 ? "󰖀" : "󰕿")
      color: root.isMuted ? Theme.muted : Theme.fg
      font.family: Theme.fontFamily
      font.pixelSize: 12
    }

    Text {
      id: audioLabel
      text: root.isMuted ? "Muted" : root.vol + "%"
      color: root.isMuted ? Theme.muted : Qt.alpha(Theme.fg, 0.7)
      font.family: Theme.fontFamily
      font.pixelSize: 10
    }
  }
}
