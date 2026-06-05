import QtQuick
import Quickshell.Io

import "../.."

Item {
  visible: false
  id: service

  property bool dnd: NotificationState.dnd
  property var toastModel: NotificationState.toastModel
  property int trackedCount: 0

  function setProp(path, value) {
    NotificationState[path] = value
  }

  function refreshNotifs() {
    checkProc.running = false
    checkProc.running = true
  }

  Process {
    id: checkProc
    command: [Theme.bin("get_notif_status")]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = JSON.parse(this.text)
          NotificationState.activeNotifs = data.active || []
          NotificationState.historyNotifs = data.history || []
          NotificationState.dnd = data.dnd || false
          service.dnd = NotificationState.dnd
          service.trackedCount = data.count || 0

          syncToastModel(data.active || [])
        } catch (e) {
          console.log("Failed to parse notif status: " + e)
        }
      }
    }
  }

  Timer {
    id: pollTimer
    interval: 2000
    repeat: true
    running: true
    onTriggered: service.refreshNotifs()
  }

  function syncToastModel(active) {
    var existing = {}
    for (var i = 0; i < service.toastModel.count; i++) {
      existing[service.toastModel.get(i).notifId] = i
    }

    var seen = {}
    for (var j = 0; j < active.length; j++) {
      var n = active[j]
      seen[n.id] = true
      if (existing[n.id] !== undefined) {
        service.toastModel.set(existing[n.id], {
          notifId: n.id,
          appName: n.app_name,
          appIcon: n.icon,
          summary: n.summary,
          body: n.body,
          urgency: n.urgency,
          expireTimeout: 6000
        })
      } else {
        service.toastModel.append({
          notifId: n.id,
          appName: n.app_name,
          appIcon: n.icon,
          summary: n.summary,
          body: n.body,
          urgency: n.urgency,
          expireTimeout: 6000
        })
      }
    }

    var toRemove = []
    for (var k = 0; k < service.toastModel.count; k++) {
      var id2 = service.toastModel.get(k).notifId
      if (!seen[id2]) toRemove.push(k)
    }
    for (var m = toRemove.length - 1; m >= 0; m--) {
      service.toastModel.remove(toRemove[m], 1)
    }
  }

  function toggleDnd() {
    Quickshell.execDetached([
      "swaync-client", "-d"
    ])
    setTimeout(function() { service.refreshNotifs() }, 200)
  }

  function clearAll() {
    Quickshell.execDetached(["makoctl", "dismiss", "-a"])
    service.toastModel.clear()
  }

  function dismissToast(index) {
    service.toastModel.remove(index, 1)
  }

  function dismissToastById(notifId) {
    for (var i = 0; i < service.toastModel.count; i++) {
      if (service.toastModel.get(i).notifId === notifId) {
        service.toastModel.remove(i, 1)
        break
      }
    }
  }

  function dismissNotification(index) {
    var notifs = NotificationState.activeNotifs
    if (index >= 0 && index < notifs.length) {
      Quickshell.execDetached([
        "makoctl", "dismiss", "-n", String(notifs[index].id)
      ])
    }
  }
}
