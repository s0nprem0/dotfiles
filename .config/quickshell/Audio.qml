import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import Quickshell.Widgets
import QtQuick.Layouts

Rectangle {
  id: root

  Theme { id: theme }

  height: 28
  implicitWidth: audioLabel.x + audioLabel.implicitWidth + 10
  radius: 10
  color: mA.containsMouse ? Qt.alpha(theme.primary, 0.2) : Qt.alpha(theme.surface, 0.4)
  border.color: mA.containsMouse ? Qt.alpha(theme.primary, 0.3) : Qt.alpha(theme.primary, 0.1)
  border.width: 1

  property var sink: Pipewire.defaultAudioSink
  property int vol: sink ? Math.round(sink.volume * 100) : 0
  property bool isMuted: sink && sink.mute !== undefined ? sink.mute : false

  Process { id: runner }

  RowLayout {
    anchors.centerIn: parent
    spacing: 3

    Text {
      text: root.isMuted ? "󰝟" : (root.vol > 50 ? "󰕾" : root.vol > 0 ? "󰖀" : "󰕿")
      color: root.isMuted ? theme.muted : theme.fg
      font.family: theme.fontFamily
      font.pixelSize: 12
    }

    Text {
      id: audioLabel
      text: root.isMuted ? "Muted" : root.vol + "%"
      color: root.isMuted ? theme.muted : Qt.alpha(theme.fg, 0.7)
      font.family: theme.fontFamily
      font.pixelSize: 10
    }
  }

  MouseArea {
    id: mA
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: (mouse) => {
      if (mouse.button === Qt.RightButton) {
        runner.command = ["pavucontrol"]
        runner.running = true
      } else if (Pipewire.defaultAudioSink) {
        Pipewire.defaultAudioSink.mute = !Pipewire.defaultAudioSink.mute
      }
    }
    onWheel: (wheel) => {
      if (!Pipewire.defaultAudioSink) return
      var step = 0.05
      var newVol = Pipewire.defaultAudioSink.volume + (wheel.angleDelta.y > 0 ? step : -step)
      Pipewire.defaultAudioSink.volume = Math.max(0, Math.min(1, newVol))
    }
  }
}
