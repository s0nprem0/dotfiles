import Quickshell.Services.Notifications
import QtQuick
import QtQml.Models

import "../../NotificationState.js" as State

Item {
  visible: false
  id: service

  property bool dnd: false
  property ListModel toastModel: ListModel {}
  readonly property int trackedCount: notifServer.trackedNotifications.count

  NotificationServer {
    id: notifServer
    keepOnReload: true

    onNotification: function(notification) {
      notification.tracked = true

      if (!service.dnd) {
        service.toastModel.append({
          notifId: notification.id,
          appName: notification.appName,
          appIcon: notification.appIcon,
          summary: notification.summary,
          body: notification.body,
          urgency: notification.urgency,
          expireTimeout: notification.expireTimeout
        })

        while (service.toastModel.count > 5) {
          service.toastModel.remove(0)
        }
      }
    }
  }

  onDndChanged: { State.dnd = dnd }

  Component.onCompleted: {
    State.server = notifServer
    State.dnd = dnd
    State.toastModel = toastModel
  }

  function toggleDnd() { dnd = !dnd }

  function clearAll() {
    var model = notifServer.trackedNotifications
    while (model.count > 0) {
      var notif = model.get(model.count - 1)
      notif.dismiss()
    }
    toastModel.clear()
  }

  function dismissToast(index) {
    toastModel.remove(index, 1)
  }

  function dismissNotification(index) {
    var model = notifServer.trackedNotifications
    if (index >= 0 && index < model.count) {
      model.get(index).dismiss()
    }
  }
}
