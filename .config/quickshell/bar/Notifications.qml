import QtQuick

import "../components"
import "../service"

BarModule {
  id: root

  implicitWidth: notifText.implicitWidth + 12 + (badge.visible ? badge.width + 2 : 0)

  property var notifService: null
  property int notifCount: notifService ? notifService.trackedCount : 0

  acceptedButtons: Qt.LeftButton | Qt.RightButton

  Connections {
    target: mA
    function onClicked(mouse) {
      if (mouse.button === Qt.RightButton) {
        if (NotificationState.service) NotificationState.service.toggleDnd()
      } else {
        if (NotificationState.centerPopup) {
          NotificationState.centerPopup.showPopup = true
        }
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

  Rectangle {
    id: badge
    visible: notifCount > 0 && !NotificationState.dnd
    width: badgeText.implicitWidth + 6
    height: 12
    radius: 6
    color: Theme.error
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: -2
    anchors.rightMargin: -2
    Text {
      id: badgeText
      anchors.centerIn: parent
      text: notifCount > 99 ? "99+" : notifCount.toString()
      color: Theme.bg
      font.family: Theme.fontFamily
      font.pixelSize: 7
      font.bold: true
    }
  }
}
