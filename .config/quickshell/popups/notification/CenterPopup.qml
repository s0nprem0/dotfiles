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

    // ─── Notification list (refreshed dynamically) ─────────────────
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

    function selectionCount() {
        var count = 0
        for (var k in root.selectedIds) { if (root.selectedIds[k]) count++ }
        return count
    }

    function toggleSelectAll() {
        var all = true
        for (var i = 0; i < root.notificationItems.length; i++) {
            if (!root.selectedIds[root.notificationItems[i].id]) { all = false; break }
        }
        var newSel = {}
        if (!all) {
            for (var j = 0; j < root.notificationItems.length; j++)
                newSel[root.notificationItems[j].id] = true
        }
        root.selectedIds = newSel
    }

    Connections {
        target: NotificationState.service
        enabled: NotificationState.service !== null
        function onNotifListChanged() { refreshNotifications() }
    }

    // ─── Clock Timer (only when any popup is visible) ─────────────
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

    // ─── Uptime Process ───────────────────────────────────────────
    Process {
        id: uptimeProc
        command: ["uptime", "-p"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text) root.uptimeStr = this.text.trim().replace(/^up /i, "")
            }
        }
    }

    // ─── Audio Muted Status ───────────────────────────────────────
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

    // ─── Bluetooth Status ─────────────────────────────────────────
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

    // ─── Wi‑Fi Status via NetworkState ────────────────────────────
    Connections {
        target: NetworkState
        function onNetworkDataChanged() {
            var data = NetworkState.networkData
            if (data) root.wifiEnabled = data.wifi_enabled
        }
    }

    // ─── Unified polling timer (only when any popup is visible) ───
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

    // ─── Periodic refresh for external closes ────────────────────
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            if (NotificationState.service)
                notificationItems = NotificationState.service.notifList.filter(n => root.showHistory ? n.closed : !n.closed)
        }
    }

    // ─── Helper Functions ─────────────────────────────────────────
    function closePopup() { root.showPopup = false }
    function formatTime(dateObj) {
        if (!dateObj) return ""
        var h = dateObj.getHours().toString().padStart(2, "0")
        var m = dateObj.getMinutes().toString().padStart(2, "0")
        return h + ":" + m
    }
    function iconFromString(value) {
        if (!value) return ""
        var name = String(value)
        var substitutions = {
            "code": "visual-studio-code",
            "code-url-handler": "visual-studio-code",
            "code-insiders": "visual-studio-code-insiders",
            "codium": "vscodium",
            "ghostty": "com.mitchellh.ghostty",
            "google-chrome": "google-chrome",
            "org.wezfurlong.wezterm": "org.wezfurlong.wezterm",
            "vesktop": "vesktop",
            "wezterm": "org.wezfurlong.wezterm",
            "zen": "zen-browser"
        }
        var lower = name.toLowerCase()
        if (substitutions[name] && Quickshell.iconPath(substitutions[name], true))
            return substitutions[name]
        if (substitutions[lower] && Quickshell.iconPath(substitutions[lower], true))
            return substitutions[lower]
        if (Quickshell.iconPath(name, true))
            return name
        if (Quickshell.iconPath(lower, true))
            return lower
        var lastDomainPart = name.split(".").pop()
        if (lastDomainPart && Quickshell.iconPath(lastDomainPart, true))
            return lastDomainPart
        if (lastDomainPart && Quickshell.iconPath(lastDomainPart.toLowerCase(), true))
            return lastDomainPart.toLowerCase()
        var kebab = lower.replace(/\s+/g, "-").replace(/_/g, "-")
        if (Quickshell.iconPath(kebab, true))
            return kebab
        return ""
    }
    function getCalendarDays(offset) {
        var date = new Date()
        date.setMonth(date.getMonth() + offset)
        var year = date.getFullYear()
        var month = date.getMonth()
        var firstDay = new Date(year, month, 1)
        var startDayOfWeek = firstDay.getDay()
        var numDays = new Date(year, month + 1, 0).getDate()
        var numDaysPrev = new Date(year, month, 0).getDate()
        var days = []
        for (var i = startDayOfWeek - 1; i >= 0; i--)
            days.push({ day: numDaysPrev - i, isCurrentMonth: false, isToday: false })
        var todayDate = new Date()
        for (var d = 1; d <= numDays; d++) {
            var isToday = (todayDate.getDate() === d && todayDate.getMonth() === month && todayDate.getFullYear() === year)
            days.push({ day: d, isCurrentMonth: true, isToday: isToday })
        }
        var remaining = 42 - days.length
        for (var n = 1; n <= remaining; n++)
            days.push({ day: n, isCurrentMonth: false, isToday: false })
        return days
    }

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
                    notifListView.currentIndex = selectedNotifIndex
                    notifListView.positionViewAtIndex(selectedNotifIndex, ListView.Contain)
                }

                function selectPrev() {
                    if (root.notificationItems.length === 0) return
                    selectedNotifIndex = Math.max(selectedNotifIndex - 1, 0)
                    notifListView.currentIndex = selectedNotifIndex
                    notifListView.positionViewAtIndex(selectedNotifIndex, ListView.Contain)
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
                    id:panel
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

                        // ── Row: Calendar + Clock ──────────────────────────
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 20

                            // Calendar column (left)
                            ColumnLayout {
                                Layout.preferredWidth: 140
                                spacing: 6

                                // Month header with arrows
                                RowLayout {
                                    spacing: 8
                                    Text {
                                        text: {
                                            var date = new Date()
                                            date.setMonth(date.getMonth() + win.calendarMonthOffset)
                                            var months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
                                            return months[date.getMonth()] + " " + date.getFullYear()
                                        }
                                        color: Theme.primary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        font.bold: true
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            hoverEnabled: true
                                            onClicked: win.calendarMonthOffset = 0
                                        }
                                    }
                                    Text {
                                        text: ""
                                        color: Theme.primary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            hoverEnabled: true
                                            onEntered: parent.color = Qt.lighter(Theme.primary, 1.2)
                                            onExited: parent.color = Theme.primary
                                            onClicked: win.calendarMonthOffset -= 1
                                        }
                                    }
                                    Text {
                                        text: ""
                                        color: Theme.primary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            hoverEnabled: true
                                            onEntered: parent.color = Qt.lighter(Theme.primary, 1.2)
                                            onExited: parent.color = Theme.primary
                                            onClicked: win.calendarMonthOffset += 1
                                        }
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: win.showCalendar ? "" : ""
                                        color: Theme.muted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            hoverEnabled: true
                                            onEntered: parent.color = Theme.primary
                                            onExited: parent.color = Theme.muted
                                            onClicked: win.showCalendar = !win.showCalendar
                                        }
                                    }
                                }

                                // Day names
                                RowLayout {
                                    Layout.fillWidth: true
                                    visible: win.showCalendar
                                    Repeater {
                                        model: ["S","M","T","W","T","F","S"]
                                        delegate: Text {
                                            Layout.fillWidth: true
                                            horizontalAlignment: Text.AlignHCenter
                                            text: modelData
                                            color: Theme.primary
                                            opacity: 0.5
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 9
                                            font.bold: true
                                        }
                                    }
                                }

                                // Calendar grid – improved with equal cell sizing
                                GridLayout {
                                    Layout.fillWidth: true
                                    visible: win.showCalendar
                                    columns: 7
                                    rows: 6
                                    rowSpacing: 2
                                    columnSpacing: 0

                                    Repeater {
                                        id: calendarRepeater
                                        model: getCalendarDays(win.calendarMonthOffset)

                                        delegate: Rectangle {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            Layout.minimumWidth: 20
                                            Layout.preferredHeight: 18
                                            color: modelData.isToday ? Theme.primary : "transparent"

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.day
                                                color: modelData.isToday ? Theme.bg : Theme.primary
                                                opacity: modelData.isToday ? 1 : (modelData.isCurrentMonth ? 0.85 : 0.3)
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 9
                                                font.bold: modelData.isToday
                                            }
                                        }
                                    }
                                }
                            }

                            // Digital clock column
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    text: root.hourStr
                                    color: Theme.primary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 28
                                    font.bold: true
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Text {
                                    text: root.minStr
                                    color: Theme.primary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 24
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                RowLayout {
                                    spacing: 4
                                    Layout.alignment: Qt.AlignHCenter
                                    Text { text: root.secStr; color: Theme.primary; font.family: Theme.fontFamily; font.pixelSize: 11 }
                                    Text { text: root.ampmStr; color: Theme.primary; font.family: Theme.fontFamily; font.pixelSize: 11 }
                                }
                                Item { height: 4 }
                                Text {
                                    text: root.uptimeStr
                                    color: Theme.primary
                                    opacity: 0.75
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Theme.primary
                            opacity: 0.15
                        }

                        // ── Notifications section (scrollable) ──────────────
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Text {
                                    text: root.showHistory ? "History" : "Notifications"
                                    color: Theme.primary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    font.bold: true
                                    opacity: 0.6
                                }
                                Text {
                                    text: "(" + root.notificationItems.length + ")"
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: root.showHistory ? "Clear" : "Dismiss Selected (" + root.selectionCount() + ")"
                                    color: root.selectionCount() > 0 ? Theme.error : Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    font.bold: root.selectionCount() > 0
                                    visible: root.showHistory ? (NotificationState.service && root.notificationItems.length > 0) : root.selectionCount() > 0
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onEntered: parent.color = Qt.lighter(root.selectionCount() > 0 ? Theme.error : Theme.muted, 1.2)
                                        onExited: parent.color = root.selectionCount() > 0 ? Theme.error : Theme.muted
                                        onClicked: {
                                            if (root.showHistory) {
                                                if (NotificationState.service) NotificationState.service.clearHistory()
                                            } else if (NotificationState.service) {
                                                var ids = []
                                                for (var k in root.selectedIds) { if (root.selectedIds[k]) ids.push(k) }
                                                NotificationState.service.dismissSelected(ids)
                                                root.selectedIds = ({})
                                            }
                                        }
                                    }
                                }
                                Text {
                                    text: root.selectionCount() > 0 && root.selectionCount() < root.notificationItems.length ? "Select All" : "Select None"
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    visible: root.selectionCount() > 0
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onEntered: parent.color = Theme.primary
                                        onExited: parent.color = Theme.muted
                                        onClicked: root.toggleSelectAll()
                                    }
                                }
                                Text {
                                    text: "Clear All"
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    visible: !root.showHistory && root.selectionCount() === 0 && root.notificationItems.length > 0
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onEntered: parent.color = Theme.primary
                                        onExited: parent.color = Theme.muted
                                        onClicked: { if (NotificationState.service) NotificationState.service.clearAll() }
                                    }
                                }
                                Text {
                                    text: "🔇 DND"
                                    color: Theme.error
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    font.bold: true
                                    visible: NotificationState.dnd
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onEntered: parent.color = Qt.lighter(Theme.error, 1.2)
                                        onExited: parent.color = Theme.error
                                        onClicked: { if (NotificationState.service) NotificationState.service.toggleDnd() }
                                    }
                                }
                                Text {
                                    text: root.showHistory ? "Active" : "History"
                                    color: Theme.primary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    font.bold: true
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onEntered: parent.color = Qt.lighter(Theme.primary, 1.2)
                                        onExited: parent.color = Theme.primary
                                        onClicked: {
                                            root.showHistory = !root.showHistory
                                            root.selectedIds = ({})
                                            root.refreshNotifications()
                                        }
                                    }
                                }
                            }

                            ScrollView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.minimumHeight: 100
                                clip: true
                                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                                ListView {
                                    id: notifListView
                                    width: parent.width
                                    height: parent.height
                                    model: root.notificationItems
                                    spacing: 8
                                    highlightMoveDuration: 0
                                    highlightResizeDuration: 0

                                    delegate: Rectangle {
                                        id: notifDelegate
                                        required property var modelData
                                        width: ListView.view.width
                                        height: notifContent.implicitHeight + 12
                                        clip: true
                                        color: notifMa.containsMouse ? Qt.alpha(Theme.primary, 0.08) : Theme.surface
                                        border.width: ListView.isCurrentItem ? 2 : 1
                                        border.color: ListView.isCurrentItem ? Theme.primary : (modelData.urgency === 2 ? Theme.error : Theme.surfaceLighter)
                                        radius: 0
                                        opacity: notif.closed ? 0.5 : 1
                                        property var notif: modelData

                                        ColumnLayout {
                                            id: notifContent
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 6

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6
                                                Rectangle {
                                                    width: 12; height: 12
                                                    color: root.selectedIds[notif.id] ? Theme.primary : "transparent"
                                                    radius: 2
                                                    border.width: root.selectedIds[notif.id] ? 0 : 1
                                                    border.color: Theme.muted
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    visible: !root.showHistory
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            var newSel = {}
                                                            for (var k in root.selectedIds) newSel[k] = root.selectedIds[k]
                                                            if (newSel[notif.id]) delete newSel[notif.id]
                                                            else newSel[notif.id] = true
                                                            root.selectedIds = newSel
                                                        }
                                                    }
                                                }
                                                Rectangle {
                                                    width: 6; height: 6
                                                    color: notif.unread ? Theme.primary : "transparent"
                                                    radius: 3
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                                Rectangle {
                                                    width: 24; height: 24
                                                    color: "transparent"
                                                    visible: notif.appIcon && notif.appIcon.length > 0
                                                    Image {
                                                        anchors.fill: parent
                                                        source: {
                                                            var icon = root.iconFromString(notif.appIcon)
                                                            if (icon) return "image://icon/" + icon
                                                            if (notif.appIcon.startsWith("/")) return "file://" + notif.appIcon
                                                            return "image://icon/" + notif.appIcon
                                                        }
                                                        fillMode: Image.PreserveAspectFit
                                                    }
                                                }
                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 1
                                                    Text {
                                                        text: notif.appName || ""
                                                        color: Theme.muted
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 8
                                                        font.bold: true
                                                        elide: Text.ElideRight
                                                        Layout.fillWidth: true
                                                        visible: text.length > 0
                                                    }
                                                    Text {
                                                        text: notif.summary
                                                        color: Theme.fg
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 10
                                                        font.bold: true
                                                        wrapMode: Text.Wrap
                                                        Layout.fillWidth: true
                                                    }
                                                    Text {
                                                        text: notif.time ? notif.timeStr : ""
                                                        color: Theme.muted
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 8
                                                    }
                                                }
                                                Text {
                                                    text: notif.closed ? "" : "✕"
                                                    color: Theme.muted
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 9
                                                    visible: !notif.closed
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        hoverEnabled: true
                                                        onEntered: parent.color = Theme.error
                                                        onExited: parent.color = Theme.muted
                                                        onClicked: {
                                                            if (NotificationState.service && notif)
                                                                NotificationState.service.dismissNotification(notif.id)
                                                        }
                                                    }
                                                }
                                            }

                                            Text {
                                                text: notif.body
                                                color: Theme.muted
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 9
                                                textFormat: Text.StyledText
                                                wrapMode: Text.Wrap
                                                Layout.fillWidth: true
                                                elide: root.expandedNotifIds[notif.id] ? Text.ElideNone : Text.ElideRight
                                                maximumLineCount: root.expandedNotifIds[notif.id] ? 99 : 2
                                                onLinkActivated: (link) => Qt.openUrlExternally(link)
                                            }

                                            Image {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 120
                                                fillMode: Image.PreserveAspectFit
                                                clip: true
                                                source: notif.image ? (notif.image.startsWith("/") ? ("file://" + notif.image) : notif.image) : ""
                                                visible: notif.image && notif.image.length > 0
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6
                                                visible: notif.actions && notif.actions.length > 0
                                                Repeater {
                                                    model: notif.actions
                                                    delegate: Rectangle {
                                                        required property var modelData
                                                        implicitHeight: 24
                                                        implicitWidth: actLabel.implicitWidth + 12
                                                        color: Theme.surfaceLighter
                                                        radius: 3
                                                        border.width: 1
                                                        border.color: Qt.alpha(Theme.primary, 0.2)
                                                        Text {
                                                            id: actLabel
                                                            anchors.centerIn: parent
                                                            text: modelData.label || "unknown"
                                                            color: Theme.fg
                                                            font.family: Theme.fontFamily
                                                            font.pixelSize: 8
                                                        }
                                                        MouseArea {
                                                            anchors.fill: parent
                                                            cursorShape: Qt.PointingHandCursor
                                                            hoverEnabled: true
                                                            onEntered: parent.color = Theme.primary
                                                            onExited: parent.color = Theme.surfaceLighter
                                                            onClicked: modelData.invoke()
                                                        }
                                                    }
                                                }
                                            }

                                            Item {
                                                Layout.fillWidth: true
                                                height: 10
                                                visible: notif.body.length > 50 || notif.body.includes("\n")
                                                Text {
                                                    anchors.right: parent.right
                                                    text: root.expandedNotifIds[notif.id] ? "less" : "more"
                                                    color: Theme.primary
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 8
                                                    font.bold: true
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        hoverEnabled: true
                                                        onEntered: parent.color = Qt.lighter(Theme.primary, 1.2)
                                                        onExited: parent.color = Theme.primary
                                                        onClicked: {
                                                            var newState = {}
                                                            for (var k in root.expandedNotifIds) newState[k] = root.expandedNotifIds[k]
                                                            newState[notif.id] = !newState[notif.id]
                                                            root.expandedNotifIds = newState
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: notifMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        acceptedButtons: Qt.LeftButton
                                        onClicked: {
                                            if (notif && notif.notification) {
                                                if (notif.notification.defaultAction)
                                                    notif.notification.defaultAction.invoke()
                                                else if (notif.actions && notif.actions.length > 0)
                                                    notif.actions[0].invoke()
                                            }
                                        }
                                    }
                                }

                                Item {
                                    anchors.fill: parent
                                    visible: root.notificationItems.length === 0
                                    Text {
                                        anchors.centerIn: parent
                                        text: root.showHistory ? "No history" : "No notifications"
                                        color: Theme.primary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 9
                                        opacity: 0.4
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Theme.primary
                            opacity: 0.15
                        }

                        // ── Quick action buttons (improved UX) ──────────────
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            // Audio Mute
                            Item {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                Text {
                                    anchors.centerIn: parent
                                    text: root.audioMuted ? "󰝟" : "󰕾"
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 16
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onEntered: parent.children[0].color = Theme.primary
                                    onExited: parent.children[0].color = Theme.muted
                                    onClicked: {
                                        Quickshell.execDetached(["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"])
                                    }
                                }
                            }

                            // Wi-Fi (opens network popup)
                            Item {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                Text {
                                    anchors.centerIn: parent
                                    text: root.wifiEnabled ? "󰖩" : "󰖪"
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 16
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onEntered: parent.children[0].color = Theme.primary
                                    onExited: parent.children[0].color = Theme.muted
                                    onClicked: {
                                        if (NetworkState.popup) {
                                            NetworkState.popup.showPopup = !NetworkState.popup.showPopup
                                        }
                                    }
                                }
                            }

                            // Bluetooth
                            Item {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                Text {
                                    anchors.centerIn: parent
                                    text: root.btEnabled ? "󰂯" : "󰂲"
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 16
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onEntered: parent.children[0].color = Theme.primary
                                    onExited: parent.children[0].color = Theme.muted
                                    onClicked: {
                                        Quickshell.execDetached(["bluetoothctl", "power", root.btEnabled ? "off" : "on"])
                                    }
                                }
                            }

                            // Brightness: left click +, right click –, middle click 50%
                            Item {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰃠"
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 16
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onEntered: parent.children[0].color = Theme.primary
                                    onExited: parent.children[0].color = Theme.muted
                                    onClicked: (mouse) => {
                                        if (mouse.button === Qt.LeftButton)
                                            Quickshell.execDetached(["brightnessctl", "set", "5%+"])
                                        else if (mouse.button === Qt.RightButton)
                                            Quickshell.execDetached(["brightnessctl", "set", "5%-"])
                                        else if (mouse.button === Qt.MiddleButton)
                                            Quickshell.execDetached(["brightnessctl", "set", "50%"])
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // Current time (digital) in footer
                            Text {
                                text: formatTime(new Date())
                                color: Theme.primary
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.bold: true
                            }
                        }
                    }
                }
            }
        }
    }
}