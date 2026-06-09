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

  DataModule {
    id: audioData
    path: Theme.bin("get_audio_status")
    interval: 1000
    onDataReceived: function(j) {
      root.vol = j.volume ?? 0
      root.isMuted = j.muted ?? false
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
        audioGui.command = ["pavucontrol"]
        audioGui.running = true
      } else {
        audioAction.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
        audioAction.running = true
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
