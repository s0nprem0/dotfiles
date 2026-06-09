import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "../../service"

Item {
    id: root

    property bool showPopup: false
    property string hourStr: ""
    property string minStr: ""
    property string secStr: ""
    property string ampmStr: ""
    property string uptimeStr: ""
    property var expandedNotifIds: ({})
    property bool btEnabled: false
    property bool wifiEnabled: false
    property bool audioMuted: false

    property var notificationItems: []
    property bool showHistory: false
    property var selectedIds: ({})

    function refreshNotifications() {
        if (!NotificationState.service) return
        if (root.showHistory)
            notificationItems = NotificationState.service.notifList.filter(n => n.closed)
        else
            notificationItems = NotificationState.service.notifList.filter(n => !n.closed)
    }

    Connections {
        target: NotificationState.service
        enabled: NotificationState.service !== null
        function onNotifListChanged() { refreshNotifications() }
    }

    Timer {
        id: clockTimer
        interval: 1000
        repeat: true
        running: false
        onTriggered: {
            var now = new Date()
            var hours = now.getHours()
            var ampm = hours >= 12 ? "PM" : "AM"
            hours = hours % 12 || 12
            root.hourStr = hours.toString().padStart(2, " ")
            root.minStr = now.getMinutes().toString().padStart(2, "0")
            root.secStr = now.getSeconds().toString().padStart(2, "0")
            root.ampmStr = ampm
        }
    }

    Process {
        id: uptimeProc
        command: ["uptime", "-p"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text) root.uptimeStr = this.text.trim().replace(/^up /i, "")
            }
        }
    }

    Process {
        id: audioProc
        command: [Theme.helperDir + "/get_audio_status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var json = JSON.parse(this.text)
                    root.audioMuted = json.muted || false
                } catch(e) {}
            }
        }
    }

    Process {
        id: btProc
        command: [Theme.helperDir + "/get_bluetooth_status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var json = JSON.parse(this.text)
                    root.btEnabled = json.enabled || false
                } catch(e) {}
            }
        }
    }

    Connections {
        target: NetworkState
        function onNetworkDataChanged() {
            var data = NetworkState.networkData
            if (data) root.wifiEnabled = data.wifi_enabled
        }
    }

    Timer {
        id: pollTimer
        interval: 5000
        repeat: true
        running: false
        onTriggered: {
            if (!uptimeProc.running) uptimeProc.running = true
            if (!audioProc.running) audioProc.running = true
            if (!btProc.running) btProc.running = true
        }
    }

    Component.onCompleted: {
        refreshNotifications()
        uptimeProc.running = true
        audioProc.running = true
        btProc.running = true
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            if (NotificationState.service)
                notificationItems = NotificationState.service.notifList.filter(n => root.showHistory ? n.closed : !n.closed)
        }
    }

    function closePopup() { root.showPopup = false }

    // ─── Popup Windows (per‑screen) ───────────────────────────────
    Variants {
        id: variantRepeater
        model: Quickshell.screens
        delegate: Component {
            PanelWindow {
                id: win
                required property var modelData
                visible: false

                property bool isClosing: false
                property real animLeftMargin: -360
                property real animOpacity: 0
                property bool showPopup: root.showPopup
                property bool winVisible: false
                property int calendarMonthOffset: 0
                property bool showCalendar: true
                property int selectedNotifIndex: -1

                function selectNext() {
                    var len = root.notificationItems.length
                    if (len === 0) return
                    selectedNotifIndex = Math.min(selectedNotifIndex + 1, len - 1)
                    notifListComp.listView.currentIndex = selectedNotifIndex
                    notifListComp.listView.positionViewAtIndex(selectedNotifIndex, ListView.Contain)
                }

                function selectPrev() {
                    if (root.notificationItems.length === 0) return
                    selectedNotifIndex = Math.max(selectedNotifIndex - 1, 0)
                    notifListComp.listView.currentIndex = selectedNotifIndex
                    notifListComp.listView.positionViewAtIndex(selectedNotifIndex, ListView.Contain)
                }

                function markAllRead() {
                    for (var i = 0; i < root.notificationItems.length; i++)
                        root.notificationItems[i].unread = false
                }

                onVisibleChanged: {
                    winVisible = visible
                    if (visible) {
                        refreshNotifications()
                        pollTimer.running = true
                        clockTimer.running = true
                    } else {
                        var anyVisible = false
                        for (var i = 0; i < variantRepeater.count; i++) {
                            var w = variantRepeater.itemAt(i)
                            if (w && w !== win && w.visible) anyVisible = true
                        }
                        if (!anyVisible) {
                            pollTimer.running = false
                            clockTimer.running = false
                        }
                    }
                }

                onShowPopupChanged: {
                    if (root.showPopup) {
                        exitAnim.stop()
                        isClosing = false
                        animLeftMargin = -360
                        animOpacity = 0
                        win.visible = true
                        introAnim.start()
                        refreshNotifications()
                        win.markAllRead()
                    } else if (!isClosing) {
                        introAnim.stop()
                        closeAnim()
                    }
                }

                function closeAnim() {
                    if (isClosing) return
                    isClosing = true
                    root.showPopup = false
                    exitAnim.start()
                }

                screen: modelData
                color: "transparent"
                exclusionMode: PanelWindow.ExclusionMode.Ignore
                focusable: true
                implicitWidth: 380
                implicitHeight: Math.min(mainLayout.implicitHeight + 32, 720)

                anchors { left: true }
                margins { left: win.animLeftMargin }

                ParallelAnimation {
                    id: introAnim
                    NumberAnimation { target: win; property: "animLeftMargin"; from: -360; to: 48; duration: 140; easing.type: Easing.OutCubic }
                    NumberAnimation { target: win; property: "animOpacity"; from: 0; to: 1; duration: 140; easing.type: Easing.OutCubic }
                }
                ParallelAnimation {
                    id: exitAnim
                    onStopped: win.visible = false
                    NumberAnimation { target: win; property: "animLeftMargin"; from: 48; to: -360; duration: 120; easing.type: Easing.InCubic }
                    NumberAnimation { target: win; property: "animOpacity"; from: 1; to: 0; duration: 120; easing.type: Easing.InCubic }
                }

                HyprlandFocusGrab {
                    active: !win.isClosing && win.visible
                    windows: [win]
                    onCleared: {
                        if (root.showPopup) win.closeAnim()
                    }
                }

                Rectangle {
                    id: panel
                    anchors.fill: parent
                    opacity: win.animOpacity
                    color: Theme.bg
                    border.width: 1
                    border.color: Theme.primary
                    radius: 0
                    focus: true

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) win.closeAnim()
                        else if (event.key === Qt.Key_Down) { win.selectNext(); event.accepted = true }
                        else if (event.key === Qt.Key_Up) { win.selectPrev(); event.accepted = true }
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                            if (win.selectedNotifIndex >= 0 && win.selectedNotifIndex < root.notificationItems.length) {
                                var n = root.notificationItems[win.selectedNotifIndex]
                                if (n && n.notification) {
                                    if (n.notification.defaultAction)
                                        n.notification.defaultAction.invoke()
                                    else if (n.actions && n.actions.length > 0)
                                        n.actions[0].invoke()
                                }
                            }
                            event.accepted = true
                        }
                    }

                    ColumnLayout {
                        id: mainLayout
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 16

                        CalendarWidget {
                            id: calendarWidget
                            Layout.fillWidth: true
                            calendarMonthOffset: win.calendarMonthOffset
                            showCalendar: win.showCalendar
                            hourStr: root.hourStr
                            minStr: root.minStr
                            secStr: root.secStr
                            ampmStr: root.ampmStr
                            uptimeStr: root.uptimeStr
                            onCalendarMonthOffsetChanged: win.calendarMonthOffset = calendarWidget.calendarMonthOffset
                            onShowCalendarChanged: win.showCalendar = calendarWidget.showCalendar
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Theme.primary
                            opacity: 0.15
                        }

                        NotificationList {
                            id: notifListComp
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            notificationItems: root.notificationItems
                            showHistory: root.showHistory
                            selectedIds: root.selectedIds
                            expandedNotifIds: root.expandedNotifIds

                            onShowHistoryChanged: {
                                root.showHistory = notifListComp.showHistory
                                root.selectedIds = ({})
                                root.refreshNotifications()
                            }
                            onSelectedIdsChanged: root.selectedIds = notifListComp.selectedIds
                            onExpandedNotifIdsChanged: root.expandedNotifIds = notifListComp.expandedNotifIds

                            onDismissSelected: (ids) => {
                                if (NotificationState.service) {
                                    NotificationState.service.dismissSelected(ids)
                                    root.selectedIds = ({})
                                }
                            }
                            onClearAll: { if (NotificationState.service) NotificationState.service.clearAll() }
                            onClearHistory: { if (NotificationState.service) NotificationState.service.clearHistory() }
                            onToggleDnd: { if (NotificationState.service) NotificationState.service.toggleDnd() }
                            onDismissNotification: (id) => {
                                if (NotificationState.service) NotificationState.service.dismissNotification(id)
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Theme.primary
                            opacity: 0.15
                        }

                        QuickActions {
                            id: quickActions
                            Layout.fillWidth: true
                            audioMuted: root.audioMuted
                            wifiEnabled: root.wifiEnabled
                            btEnabled: root.btEnabled
                            onToggleNetworkPopup: {
                                if (NetworkState.popup)
                                    NetworkState.popup.showPopup = !NetworkState.popup.showPopup
                            }
                        }
                    }
                }
            }
        }
    }
}
