import Quickshell
import Quickshell.Io
import QtQuick
import Quickshell.Widgets

Rectangle {
  id: root

  Theme { id: theme }

  height: 28
  width: 32
  radius: 10
  color: mA.containsMouse ? Qt.alpha(theme.primary, 0.2) : Qt.alpha(theme.surface, 0.4)
  border.color: mA.containsMouse ? Qt.alpha(theme.primary, 0.3) : Qt.alpha(theme.primary, 0.1)
  border.width: 1

  property int count: 0
  property bool dnd: false

  Process {
    id: notifHelper
    command: [Quickshell.env("HOME") + "/.config/quickshell/helpers/get_notif_status"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var j = JSON.parse(this.text)
          root.count = j.count
          root.dnd = j.dnd
        } catch (e) {}
      }
    }
  }

  Process { id: notifRunner }

  Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: notifHelper.running = true
  }

  Component.onCompleted: notifHelper.running = true

  Text {
    anchors.centerIn: parent
    text: {
      if (root.dnd) return "󰂛"
      if (root.count > 0) return "󰂚"
      return "󰂜"
    }
    color: root.dnd ? theme.muted : (root.count > 0 ? theme.primary : theme.fg)
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
      text: root.dnd ? "Do Not Disturb" : (root.count > 0 ? root.count + " notification(s)" : "No notifications")
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
        notifRunner.command = ["swaync-client", "--toggle-dnd"]
        notifRunner.running = true
      } else {
        notifRunner.command = ["swaync-client", "--toggle-panel"]
        notifRunner.running = true
      }
    }
  }
}
