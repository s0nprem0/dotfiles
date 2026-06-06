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
    property var notifList: []
    property int trackedCount: 0

    property alias server: notifServer

    Component {
        id: notifDataComp
        NotifData {}
    }

    NotificationServer {
        id: notifServer
        keepOnReload: true
        actionsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true

        onNotification: (notification) => {
            var data = notifDataComp.createObject(service, {
                notification: notification
            })

            var list = service.notifList.slice()
            list.unshift(data)
            service.notifList = list

            if (!service.dnd) {
                toastModel.insert(0, {
                    notifId: notification.id,
                    appName: notification.appName,
                    appIcon: notification.appIcon,
                    summary: notification.summary,
                    body: notification.body,
                    urgency: notification.urgency,
                    expireTimeout: notification.expireTimeout,
                    timestamp: new Date(),
                    notifData: data
                })
                while (toastModel.count > service.maxToasts)
                    toastModel.remove(service.maxToasts, 1)
            }
        }
    }

    function findNotification(id) {
        for (var i = 0; i < service.notifList.length; i++) {
            var n = service.notifList[i]
            if (!n.closed && n.notification && n.notification.id === id)
                return n
        }
        return null
    }

    function dismissNotification(id) {
        var n = findNotification(id)
        if (n) {
            n.close()
            service.dismissToastById(id)
            service.notifList = service.notifList.slice()
            service.recalcTrackedCount()
        }
    }

    function clearAll() {
        var list = service.notifList.slice()
        for (var i = 0; i < list.length; i++) {
            if (!list[i].closed)
                list[i].close()
        }
        service.notifList = []
        toastModel.clear()
    }

    function toggleDnd() {
        dnd = !dnd
    }

    function dismissToast(index) {
        var item = toastModel.get(index)
        if (item && item.notifData)
            item.notifData.close()
        toastModel.remove(index, 1)
        service.notifList = service.notifList.slice()
        service.recalcTrackedCount()
    }

    function dismissToastById(id) {
        for (var i = toastModel.count - 1; i >= 0; i--) {
            var item = toastModel.get(i)
            if (item.notifId === id) {
                if (item.notifData) item.notifData.close()
                toastModel.remove(i, 1)
                service.notifList = service.notifList.slice()
                service.recalcTrackedCount()
                return
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: service.recalcTrackedCount()
    }

    function recalcTrackedCount() {
        var count = 0
        for (var i = 0; i < service.notifList.length; i++) {
            if (!service.notifList[i].closed)
                count++
        }
        service.trackedCount = count
    }

    onNotifListChanged: service.recalcTrackedCount()

    onDndChanged: {
        if (typeof NotificationState !== "undefined")
            NotificationState.dnd = dnd
    }

    Component.onCompleted: {
        if (typeof NotificationState !== "undefined") {
            NotificationState.service = service
            NotificationState.server = notifServer
            NotificationState.toastModel = toastModel
            NotificationState.notifList = notifList
            NotificationState.dnd = dnd
        }
    }
}
