import Quickshell
import QtQuick

import "Theme.js" as Theme

BarModule {
  id: root

  width: 32

  property int count: 0
  property bool dnd: false

  DataModule {
    path: Quickshell.env("HOME") + "/.config/quickshell/helpers/get_notif_status"
    interval: 2000
    onDataReceived: function(j) {
      root.count = j.count
      root.dnd = j.dnd
    }
  }

  Process { id: notifRunner }

  mA.acceptedButtons: Qt.LeftButton | Qt.RightButton

  Connections {
    target: mA
    function onClicked(mouse) {
      if (mouse.button === Qt.RightButton) {
        notifRunner.command = ["swaync-client", "--toggle-dnd"]
        notifRunner.running = true
      } else {
        notifRunner.command = ["swaync-client", "--toggle-panel"]
        notifRunner.running = true
      }
    }
  }

  tooltipText: root.dnd ? "Do Not Disturb" : (root.count > 0 ? root.count + " notification(s)" : "No notifications")

  Text {
    anchors.centerIn: parent
    text: {
      if (root.dnd) return "󰂛"
      if (root.count > 0) return "󰂚"
      return "󰂜"
    }
    color: root.dnd ? Theme.muted : (root.count > 0 ? Theme.primary : Theme.fg)
    font.family: Theme.fontFamily
    font.pixelSize: 12
  }
}
