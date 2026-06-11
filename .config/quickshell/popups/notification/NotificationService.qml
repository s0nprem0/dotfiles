import Quickshell.Services.Notifications
import QtQuick
import QtQml.Models

import "../../service"

Item {
    visible: false
    id: service

    property bool dnd: false
    property var toastModel: ListModel { id: toastModel }
    property int maxToasts: 5
    property int maxTotal: 200
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

            // Enforce total limit (active + history)
            while (list.length > service.maxTotal) {
              var stale = list.pop()
              stale.destroy()
            }

            service.notifList = list

            if (!service.dnd || notification.urgency === 2) {
                // ── Group by app: replace existing toast from same app ──
                var groupCount = 1
                for (var i = 0; i < toastModel.count; i++) {
                    var item = toastModel.get(i)
                    if (item.appName === notification.appName) {
                        groupCount = (item.groupCount || 1) + 1
                        if (item.notifData) item.notifData.close()
                        toastModel.remove(i, 1)
                        break
                    }
                }

                toastModel.insert(0, {
                    notifId: notification.id,
                    appName: notification.appName,
                    appIcon: notification.appIcon,
                    summary: notification.summary,
                    body: notification.body,
                    urgency: notification.urgency,
                    expireTimeout: notification.expireTimeout,
                    timestamp: new Date(),
                    notifData: data,
                    groupCount: groupCount
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

    function dismissSelected(ids) {
        for (var i = 0; i < ids.length; i++) {
            var n = findNotification(ids[i])
            if (n) n.close()
            service.dismissToastById(ids[i])
        }
        service.notifList = service.notifList.slice()
        service.recalcTrackedCount()
    }

    function clearAll() {
        for (var i = 0; i < service.notifList.length; i++) {
            if (!service.notifList[i].closed)
                service.notifList[i].close()
        }
        toastModel.clear()
        service.notifList = service.notifList.slice()
        service.recalcTrackedCount()
    }

    function clearHistory() {
        for (var i = service.notifList.length - 1; i >= 0; i--) {
            if (service.notifList[i].closed) {
                service.notifList[i].destroy()
                service.notifList.splice(i, 1)
            }
        }
        service.notifList = service.notifList.slice()
        service.recalcTrackedCount()
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

    function softDismissToastById(id) {
        for (var i = toastModel.count - 1; i >= 0; i--) {
            var item = toastModel.get(i)
            if (item.notifId === id) {
                toastModel.remove(i, 1)
                service.notifList = service.notifList.slice()
                service.recalcTrackedCount()
                return
            }
        }
    }

    function recalcTrackedCount() {
        var count = 0
        for (var i = 0; i < service.notifList.length; i++) {
            if (!service.notifList[i].closed)
                count++
        }
        service.trackedCount = count
    }

    Timer {
        interval: 5000
        repeat: true
        running: service.notifList.length > 0
        onTriggered: {
            for (var i = 0; i < service.notifList.length; i++)
                service.notifList[i].updateTimeStr()
        }
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
