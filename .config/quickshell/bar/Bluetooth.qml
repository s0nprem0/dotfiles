import Quickshell
import Quickshell.Io
import QtQuick

import "../components"
import "../service"

BarModule {
  id: root

  opacity: btEnabled ? 1.0 : 0.4
  implicitWidth: btText.implicitWidth + 12

  property bool btEnabled: false
  property bool hasConnected: false
  property string btTooltip: ""

  DataModule {
    id: btData
    path: Theme.bin("get_bluetooth_status")
    interval: 5000
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

  Process { id: btToggle }
  Process { id: btLauncher }

  Connections {
    target: btToggle
    function onRunningChanged() {
      if (!btToggle.running) btData.refresh()
    }
  }

  acceptedButtons: Qt.LeftButton | Qt.RightButton

  Connections {
    target: mA
    function onClicked(mouse) {
      if (mouse.button === Qt.RightButton) {
        btLauncher.command = [Theme.config("rofi/scripts/bluetooth-manager")]
        btLauncher.running = true
      } else {
        btToggle.command = ["bluetoothctl", "power", root.btEnabled ? "off" : "on"]
        btToggle.running = true
      }
    }
  }

  tooltipText: root.btTooltip

  Text {
    id: btText
    anchors.centerIn: parent
    text: root.hasConnected ? "󰂯" : "󰂲"
    color: root.hasConnected ? Theme.primary : Theme.muted
    font.family: Theme.fontFamily
    font.pixelSize: 11
  }
}
