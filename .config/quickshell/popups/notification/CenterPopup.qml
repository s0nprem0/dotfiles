import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import "../../service"
import "../../components"

Item {
    id: root

    property bool showPopup: false
    onShowPopupChanged: {
        if (showPopup) {
            for (var i = 0; i < variantRepeater.instances.length; i++) {
                var w = variantRepeater.instances[i]
                if (w) w.visible = true
            }
            for (var i = 0; i < root.notificationItems.length; i++)
                root.notificationItems[i].unread = false
            slide.show = true
        } else if (!slide.closing) {
            slide.closeAnim()
        }
    }

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
    property var mediaData: null
    property string localArtUrl: ""
    property string pendingCacheUrl: ""
    property string diagCpu: ""
    property string diagMem: ""
    property string diagDisk: ""
    property string timeShort24h: ""

    function refreshNotifications() {
        if (!NotificationState.service) return
        if (root.showHistory)
            notificationItems = NotificationState.service.notifList.filter(n => n.closed)
        else
            notificationItems = NotificationState.service.notifList.filter(n => !n.closed)
    }

    function ensureArtCache(url) {
        if (!url || url.indexOf("://") === -1) return
        if (url.indexOf("file://") === 0) return
        if (url === root.pendingCacheUrl) return
        root.pendingCacheUrl = url
        root.localArtUrl = ""
        artCacheProc.command = ["sh", "-c",
            "url=\"$1\"\n" +
            "hash=$(echo \"$url\" | md5sum | cut -c1-16)\n" +
            "path=\"/tmp/cpopup_art_$hash\"\n" +
            "find /tmp/cpopup_art_* -mmin +60 -delete 2>/dev/null\n" +
            "[ -f \"$path\" ] || curl -sL -o \"$path\" \"$url\"\n" +
            "echo \"$url|$path\"",
            "_", url]
        artCacheProc.running = true
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
            root.timeShort24h = now.getHours().toString().padStart(2, "0") + ":" + root.minStr
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
        onExited: function(code) {
            if (code !== 0) console.warn("uptimeProc exited with code", code)
        }
    }

    Process {
        id: audioProc
        command: [Theme.bin("get_audio_status")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var json = JSON.parse(this.text)
                    root.audioMuted = json.muted || false
                    var newMedia = json.media || null
                    root.mediaData = newMedia
                    if (newMedia && newMedia.art_url) {
                        if (newMedia.art_url.indexOf("http") === 0) {
                            root.ensureArtCache(newMedia.art_url)
                        } else {
                            root.localArtUrl = newMedia.art_url.indexOf("://") !== -1 ? newMedia.art_url : "file://" + newMedia.art_url
                        }
                    } else {
                        root.localArtUrl = ""
                    }
                } catch(e) {
                    console.warn("audioProc parse error:", e)
                }
            }
        }
        onExited: function(code) {
            if (code !== 0) console.warn("audioProc exited with code", code)
        }
    }

    FileView {
        path: Theme.homeDir + "/.cache/quickshell/osd_state.json"
        onDataChanged: { if (!audioProc.running) audioProc.running = true }
    }

    Process {
        id: diagProc
        command: [Theme.bin("get_sys_diagnostics")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var json = JSON.parse(this.text)
                    root.diagCpu = json.cpu && json.cpu.temp != null ? json.cpu.temp.toFixed(0) + "°C" : ""
                    root.diagMem = json.memory && json.memory.used_gb != null ? json.memory.used_gb.toFixed(1) + "/" + json.memory.total_gb.toFixed(1) + " GB" : ""
                    root.diagDisk = json.disk && json.disk.used != null ? json.disk.used + "/" + json.disk.total : ""
                } catch(e) {
                    console.warn("diag parse error:", e)
                }
            }
        }
        onExited: function(code) {
            if (code !== 0) console.warn("diagProc exited with code", code)
        }
    }

    Process {
        id: artCacheProc
        running: false
        stdout: StdioCollector {}
        onExited: {
            var output = stdout.text.trim()
            if (output) {
                var parts = output.split("|")
                if (parts.length === 2 && parts[0] === root.pendingCacheUrl) {
                    root.localArtUrl = "file://" + parts[1]
                }
            }
        }
    }

    Process {
        id: btProc
        command: [Theme.bin("get_bluetooth_status")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var json = JSON.parse(this.text)
                    root.btEnabled = json.enabled || false
                } catch(e) {
                    console.warn("btProc parse error:", e)
                }
            }
        }
        onExited: function(code) {
            if (code !== 0) console.warn("btProc exited with code", code)
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
            if (!diagProc.running) diagProc.running = true
        }
    }

    Component.onCompleted: {
        refreshNotifications()
        uptimeProc.running = true
        audioProc.running = true
        btProc.running = true
        diagProc.running = true
    }

    Timer {
        interval: 2000
        running: root.showPopup
        repeat: true
        onTriggered: {
            if (NotificationState.service)
                notificationItems = NotificationState.service.notifList.filter(n => root.showHistory ? n.closed : !n.closed)
        }
    }

    function closePopup() { root.showPopup = false }

    SlideAnimator {
        id: slide
        slideFrom: -500
        slideTo: 48
        introDuration: 140
        exitDuration: 120
        onExitCompleted: {
            for (var i = 0; i < variantRepeater.instances.length; i++) {
                var w = variantRepeater.instances[i]
                if (w) w.visible = false
            }
        }
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
                    if (visible) {
                        refreshNotifications()
                        pollTimer.running = true
                        clockTimer.running = true
                    } else {
                        var anyVisible = false
                        for (var i = 0; i < variantRepeater.instances.length; i++) {
                            var w = variantRepeater.instances[i]
                            if (w && w !== win && w.visible) anyVisible = true
                        }
                        if (!anyVisible) {
                            pollTimer.running = false
                            clockTimer.running = false
                        }
                    }
                }

                screen: modelData
                color: "transparent"
                exclusionMode: PanelWindow.ExclusionMode.Ignore
                focusable: true
                implicitWidth: 380
                implicitHeight: Math.min(mainLayout.implicitHeight + 32, 720)

                anchors { top: true }
                margins { top: slide.animSlide }

                HyprlandFocusGrab {
                    active: win.visible
                    windows: [win]
                    onCleared: {
                        if (root.showPopup) root.closePopup()
                    }
                }

                Rectangle {
                    id: panel
                    anchors.fill: parent
                    opacity: slide.animOpacity
                    color: Theme.bg
                    border.width: 1
                    border.color: Theme.primary
                    radius: 0
                    focus: true

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) root.closePopup()
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

                        // ─── Now Playing ──────────────────────────
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.mediaData ? 48 : 0
                            visible: root.mediaData !== null
                            clip: true

                            Rectangle {
                                anchors.fill: parent
                                color: Qt.alpha(Theme.primary, 0.05)

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 8

                                    Rectangle {
                                        Layout.preferredWidth: 36; Layout.preferredHeight: 36
                                        color: Theme.surface
                                        border.width: 1
                                        border.color: Qt.alpha(Theme.primary, 0.2)

                                        Image {
                                            id: artImage
                                            anchors.fill: parent
                                            source: root.localArtUrl || ""
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            text: "♫"
                                            color: Theme.muted
                                            font.pixelSize: 14
                                            visible: !root.localArtUrl || artImage.status === Image.Error
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        spacing: 1

                                        Text {
                                            Layout.fillWidth: true
                                            text: root.mediaData ? root.mediaData.title || "Unknown" : ""
                                            color: Theme.primary
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 9
                                            font.bold: true
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: root.mediaData ? root.mediaData.artist || "" : ""
                                            color: Theme.muted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 8
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }
                                    }

                                    Text {
                                        text: root.mediaData && root.mediaData.status === "Playing" ? "" : ""
                                        color: root.mediaData && root.mediaData.status === "Playing" ? Theme.green : Theme.muted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                    }
                                }
                            }
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

                        QuickActions {
                            id: quickActions
                            Layout.fillWidth: true
                            audioMuted: root.audioMuted
                            wifiEnabled: root.wifiEnabled
                            btEnabled: root.btEnabled
                            diagCpu: root.diagCpu
                            diagMem: root.diagMem
                            diagDisk: root.diagDisk
                            timeShort24h: root.timeShort24h
                            onToggleNetworkPopup: {
                                if (NetworkState.popup)
                                    NetworkState.popup.showPopup = !NetworkState.popup.showPopup
                            }
                            onMuteToggled: root.audioMuted = !root.audioMuted
                        }
                    }
                }
            }
        }
    }
}
