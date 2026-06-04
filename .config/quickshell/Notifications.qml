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

  Process { id: notifRunner }

  property int notificationCount: 0
  property bool dnd: false

  Text {
    anchors.centerIn: parent
    text: {
      if (root.dnd) return "󰂛"
      if (root.notificationCount > 0) return "󰂚"
      return "󰂜"
    }
    color: root.dnd ? theme.muted : (root.notificationCount > 0 ? theme.primary : theme.fg)
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
      text: root.dnd ? "Do Not Disturb" : (root.notificationCount > 0 ? root.notificationCount + " notification(s)" : "No notifications")
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
