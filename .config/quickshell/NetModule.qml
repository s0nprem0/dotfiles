import Quickshell
import QtQuick
import QtQuick.Layouts

import "Theme.js" as Theme

BarModule {
  id: root

  implicitWidth: netLabel.implicitWidth + 20

  property bool networkConnected: false
  property string networkSsid: ""

  DataModule {
    path: Quickshell.env("HOME") + "/.config/quickshell/helpers/get_network_status"
    interval: 10000
    onDataReceived: function(j) {
      root.networkConnected = j.connected
      root.networkSsid = j.ssid
    }
  }

  Process { id: nmRunner }

  mA.acceptedButtons: Qt.LeftButton | Qt.RightButton

  Connections {
    target: mA
    function onClicked(mouse) {
      if (mouse.button === Qt.RightButton) {
        nmRunner.command = ["nm-connection-editor"]
        nmRunner.running = true
      } else {
        nmRunner.command = ["qs", "-p", "/home/jllyn/.config/quickshell/wifi.qml"]
        nmRunner.running = true
      }
    }
  }

  tooltipText: root.networkConnected ? root.networkSsid : "Disconnected"

  RowLayout {
    anchors.centerIn: parent
    spacing: 4

    Text {
      id: netIcon
      text: root.networkConnected ? "󰤨" : "󰤭"
      color: root.networkConnected ? Theme.fg : Theme.muted
      font.family: Theme.fontFamily
      font.pixelSize: 12
    }

    Text {
      id: netLabel
      text: root.networkConnected ? root.networkSsid : "Disconnected"
      color: root.networkConnected ? Qt.alpha(Theme.fg, 0.7) : Theme.muted
      font.family: Theme.fontFamily
      font.pixelSize: 10
      visible: text.length > 0
    }
  }
}
