import QtQuick

import ".."
import "../components"

BarModule {
  id: root

  implicitWidth: notifText.implicitWidth + 12

  required property var notifService
  property int notifCount: notifService.trackedCount

  acceptedButtons: Qt.LeftButton | Qt.RightButton

  Connections {
    target: mA
    function onClicked(mouse) {
      if (mouse.button === Qt.RightButton) {
        NotificationState.service.toggleDnd()
      } else {
        NotificationState.centerPopup.showPopup = !NotificationState.centerPopup.showPopup
      }
    }
  }

  tooltipText: NotificationState.dnd ? "Do Not Disturb" : (notifCount > 0 ? notifCount + " notification(s)" : "No notifications")

  Text {
    id: notifText
    anchors.centerIn: parent
    text: {
      if (NotificationState.dnd) return "󰂛"
      if (notifCount > 0) return "󰂚"
      return "󰂜"
    }
    color: NotificationState.dnd ? Theme.muted : (notifCount > 0 ? Theme.primary : Theme.fg)
    font.family: Theme.fontFamily
    font.pixelSize: 11
  }
}
