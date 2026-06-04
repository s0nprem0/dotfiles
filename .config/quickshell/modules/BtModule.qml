import Quickshell.Io
import QtQuick

import "../Theme.js" as Theme
import "../components"

BarModule {
  id: root

  visible: btEnabled
  width: 32

  property bool btEnabled: false
  property bool hasConnected: false
  property string btTooltip: ""

  DataModule {
    path: Theme.bin("get_bluetooth_status")
    interval: 30000
    onDataReceived: function(j) {
      root.btEnabled = j.enabled
      root.hasConnected = false
      var names = []
      for (var i = 0; i < j.devices.length; i++) {
        if (j.devices[i].connected) {
          root.hasConnected = true
          names.push(j.devices[i].name)
        }
      }
      root.btTooltip = root.hasConnected ? names.join(", ") : (j.enabled ? "No devices" : "Bluetooth off")
    }
  }

  Process { id: btRunner }

  acceptedButtons: Qt.LeftButton | Qt.RightButton

  Connections {
    target: mA
    function onClicked(mouse) {
      if (mouse.button === Qt.RightButton) {
        btRunner.command = ["/home/jllyn/.config/rofi/scripts/bluetooth-manager"]
        btRunner.running = true
      } else {
        btRunner.command = ["bluetoothctl", "power", root.btEnabled ? "off" : "on"]
        btRunner.running = true
      }
    }
  }

  tooltipText: root.btTooltip

  Text {
    anchors.centerIn: parent
    text: root.hasConnected ? "󰂯" : "󰂲"
    color: root.hasConnected ? Theme.primary : Theme.muted
    font.family: Theme.fontFamily
    font.pixelSize: 12
  }
}
