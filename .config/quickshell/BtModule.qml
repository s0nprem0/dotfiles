import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import QtQuick
import Quickshell.Widgets

Rectangle {
  id: root

  Theme { id: theme }

  visible: Bluetooth.adapters.length > 0 && Bluetooth.adapters[0].powered
  height: 28
  width: 32
  radius: 10
  color: mA.containsMouse ? Qt.alpha(theme.primary, 0.2) : Qt.alpha(theme.surface, 0.4)
  border.color: mA.containsMouse ? Qt.alpha(theme.primary, 0.3) : Qt.alpha(theme.primary, 0.1)
  border.width: 1

  Process { id: btRunner }

  property bool hasConnected: {
    for (var i = 0; i < Bluetooth.adapters.length; i++) {
      if (Bluetooth.adapters.get(i).connectedDevices.length > 0) return true
    }
    return false
  }

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
    width: tooltipText.width + 12
    radius: 4
    color: Qt.alpha(theme.surface, 0.9)
    border.color: Qt.alpha(theme.primary, 0.2)
    border.width: 1
    visible: mA.containsMouse

    Text {
      id: tooltipText
      anchors.centerIn: parent
      text: {
        if (root.hasConnected) {
          var names = []
          for (var i = 0; i < Bluetooth.adapters.length; i++) {
            var devs = Bluetooth.adapters.get(i).connectedDevices
            for (var j = 0; j < devs.length; j++)
              names.push(devs.get(j).name)
          }
          return names.join(", ")
        }
        return Bluetooth.adapters[0] && Bluetooth.adapters[0].powered ? "No devices" : "Bluetooth off"
      }
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
        var a = Bluetooth.adapters[0]
        if (a) a.powered = !a.powered
      }
    }
  }
}
