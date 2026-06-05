import QtQuick

import "../Theme.js" as Theme
import "../NotificationState.js" as State
import "../components"

BarModule {
  id: root

  implicitWidth: notifText.implicitWidth + 12

  property int notifCount: State.server ? State.server.trackedNotifications.count : 0

  acceptedButtons: Qt.LeftButton | Qt.RightButton

  Connections {
    target: mA
    function onClicked(mouse) {
      if (mouse.button === Qt.RightButton) {
        State.service.toggleDnd()
      } else {
        State.centerPopup.visible = !State.centerPopup.visible
      }
    }
  }

  tooltipText: State.dnd ? "Do Not Disturb" : (notifCount > 0 ? notifCount + " notification(s)" : "No notifications")

  Text {
    id: notifText
    anchors.centerIn: parent
    text: {
      if (State.dnd) return "󰂛"
      if (notifCount > 0) return "󰂚"
      return "󰂜"
    }
    color: State.dnd ? Theme.muted : (notifCount > 0 ? Theme.primary : Theme.fg)
    font.family: Theme.fontFamily
    font.pixelSize: 11
  }
}
