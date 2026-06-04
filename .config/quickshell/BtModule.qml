import Quickshell
import Quickshell.Io
import QtQuick
import Quickshell.Widgets

Rectangle {
  id: root

  Theme { id: theme }

  visible: btEnabled
  height: 28
  width: 32
  radius: 10
  color: mA.containsMouse ? Qt.alpha(theme.primary, 0.2) : Qt.alpha(theme.surface, 0.4)
  border.color: mA.containsMouse ? Qt.alpha(theme.primary, 0.3) : Qt.alpha(theme.primary, 0.1)
  border.width: 1

  property bool btEnabled: false
  property bool hasConnected: false
  property string tooltipText: ""

  Process {
    id: btHelper
    command: [Quickshell.env("HOME") + "/.config/quickshell/helpers/get_bluetooth_status"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var j = JSON.parse(this.text)
          root.btEnabled = j.enabled
          root.hasConnected = false
          var names = []
          for (var i = 0; i < j.devices.length; i++) {
            if (j.devices[i].connected) {
              root.hasConnected = true
              names.push(j.devices[i].name)
            }
          }
          root.tooltipText = root.hasConnected ? names.join(", ") : (j.enabled ? "No devices" : "Bluetooth off")
        } catch (e) {}
      }
    }
  }

  Process { id: btRunner }

  Timer {
    interval: 30000
    running: true
    repeat: true
    onTriggered: btHelper.running = true
  }

  Component.onCompleted: btHelper.running = true

  Text {
    anchors.centerIn: parent
    text: root.hasConnected ? "󰂯" : "󰂲"
    color: root.hasConnected ? theme.primary : theme.muted
    font.family: theme.fontFamily
    font.pixelSize: 12
  }

  Rectangle {
    id: tooltip
    anchors.bottom: parent.top
    anchors.bottomMargin: 4
    anchors.horizontalCenter: parent.horizontalCenter
    height: 20
    width: tooltipLabel.width + 12
    radius: 4
    color: Qt.alpha(theme.surface, 0.9)
    border.color: Qt.alpha(theme.primary, 0.2)
    border.width: 1
    visible: mA.containsMouse

    Text {
      id: tooltipLabel
      anchors.centerIn: parent
      text: root.tooltipText
      color: theme.fg
      font.family: theme.fontFamily
      font.pixelSize: 9
    }
  }

  MouseArea {
    id: mA
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: (mouse) => {
      if (mouse.button === Qt.RightButton) {
        btRunner.command = ["/home/jllyn/.config/rofi/scripts/bluetooth-manager"]
        btRunner.running = true
      } else {
        btRunner.command = ["bluetoothctl", "power", root.btEnabled ? "off" : "on"]
        btRunner.running = true
      }
    }
  }
}
