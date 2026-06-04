import Quickshell
import Quickshell.Io
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

  property int vol: 0
  property bool isMuted: false

  Process {
    id: audioHelper
    command: [Quickshell.env("HOME") + "/.config/quickshell/helpers/get_audio_status"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var j = JSON.parse(this.text)
          root.vol = j.volume
          root.isMuted = j.muted
        } catch (e) {}
      }
    }
  }
  
  Process { id: runner }

  Timer {
    interval: 3000
    running: true
    repeat: true
    onTriggered: audioHelper.running = true
  }

  Component.onCompleted: audioHelper.running = true

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
      } else {
        runner.command = ["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"]
        runner.running = true
      }
    }
    onWheel: (wheel) => {
      runner.command = [
        "pactl", "set-sink-volume", "@DEFAULT_SINK@",
        wheel.angleDelta.y > 0 ? "+5%" : "-5%"
      ]
      runner.running = true
    }
  }
}
