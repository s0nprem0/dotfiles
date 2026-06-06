import Quickshell.Services.Notifications
import QtQuick
import QtQml.Models

import "../.."

Item {
    visible: false
    id: service

    property bool dnd: false
    property var toastModel: ListModel { id: toastModel }
    property int maxToasts: 5
    property int trackedCount: 0

    Binding {
        target: service
        property: "trackedCount"
        value: notifServer.trackedNotifications ? notifServer.trackedNotifications.count : 0
        when: notifServer && notifServer.trackedNotifications
    }

    // Reference to the server
    property alias server: notifServer

    NotificationServer {
        id: notifServer
        keepOnReload: true
        actionsSupported: true

        // When a notification arrives
        onNotification: (notification) => {
            notification.tracked = true

            if (!service.dnd) {
                // Add to toast model
                toastModel.insert(0, {
                    notifId: notification.id,
                    appName: notification.appName,
                    appIcon: notification.appIcon,
                    summary: notification.summary,
                    body: notification.body,
                    urgency: notification.urgency,
                    expireTimeout: notification.expireTimeout,
                    timestamp: new Date(),
                    notification: notification  // keep reference for actions
                })
                // Limit to maxToasts
                while (toastModel.count > service.maxToasts)
                    toastModel.remove(service.maxToasts, 1)
            }
        }
    }

    // Helper to find a notification by id
    function findNotification(id) {
        for (var i = 0; i < notifServer.trackedNotifications.count; i++) {
            var n = notifServer.trackedNotifications.get(i)
            if (n.id === id) return n
        }
        return null
    }

    // Dismiss a single notification by id
    function dismissNotification(id) {
        var n = findNotification(id)
        if (n) n.dismiss()
    }

    // Clear all active notifications
    function clearAll() {
        var model = notifServer.trackedNotifications
        for (var i = model.count - 1; i >= 0; i--) {
            model.get(i).dismiss()
        }
        toastModel.clear()
    }

    // Toggle Do Not Disturb
    function toggleDnd() {
        dnd = !dnd
    }

    // Dismiss a toast by model index
    function dismissToast(index) {
        var item = toastModel.get(index)
        if (item && item.notification) {
            item.notification.dismiss()
        }
        toastModel.remove(index, 1)
    }

    // Dismiss a toast by notification id (race-safe: scans by id, not index)
    function dismissToastById(id) {
        for (var i = toastModel.count - 1; i >= 0; i--) {
            var item = toastModel.get(i)
            if (item.notifId === id || (item.notification && item.notification.id === id)) {
                if (item.notification) item.notification.dismiss()
                toastModel.remove(i, 1)
                return
            }
        }
    }

    // Update NotificationState singleton
    onDndChanged: {
        if (typeof NotificationState !== "undefined")
            NotificationState.dnd = dnd
    }

    Component.onCompleted: {
        if (typeof NotificationState !== "undefined") {
            NotificationState.service = service
            NotificationState.server = notifServer
            NotificationState.toastModel = toastModel
            NotificationState.dnd = dnd
        }
    }
}