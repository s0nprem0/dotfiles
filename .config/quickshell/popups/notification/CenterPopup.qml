import "../../components"
import "../../service"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Item {
    id: root

    property bool showPopup: false
    property string hourStr: ""
    property string minStr: ""
    property string secStr: ""
    property string ampmStr: ""
    property string uptimeStr: ""
    property var expandedNotifIds: ({
    })
    property bool btEnabled: false
    property bool wifiEnabled: false
    property bool audioMuted: false
    property var notificationItems: []
    property bool showHistory: false
    property var selectedIds: ({
    })
    property var mediaData: null
    property var mediaSources: []
    property string currentMediaSource: ""
    property string localArtUrl: ""
    property string diagCpu: ""
    property string diagMem: ""
    property string diagDisk: ""
    property string timeShort24h: ""
    property int visibleWindowCount: 0

    function refreshNotifications() {
        if (!NotificationState.service)
            return ;

        if (root.showHistory)
            notificationItems = NotificationState.service.notifList.filter((n) => {
            return n.closed;
        });
        else
            notificationItems = NotificationState.service.notifList.filter((n) => {
            return !n.closed;
        });
    }

    function ensureArtCache(url) {
        if (!url || url.indexOf("://") === -1)
            return ;

        if (url.indexOf("file://") === 0)
            return ;

        root.localArtUrl = "";
        artCache.ensureCached(url);
    }

    function switchPlayer() {
        var list = root.mediaSources;
        if (!root.currentMediaSource || list.length < 2)
            return ;

        var idx = 0;
        for (var i = 0; i < list.length; i++) {
            if (list[i].name === root.currentMediaSource) {
                idx = i;
                break;
            }
        }
        var next = list[(idx + 1) % list.length].name;
        persistPlayerProc.command = ["sh", "-c", "printf '%s' \"" + next.replace(/"/g, '\\"') + "\" > " + Theme.cacheDir + "/current_media_player"];
        persistPlayerProc.running = true;
        if (!audioProc.running)
            audioProc.running = true;

    }

    function closePopup() {
        root.showPopup = false;
    }

    onShowPopupChanged: {
        if (showPopup) {
            var instLen = variantRepeater.instances.length;
            for (var i = 0; i < instLen; i++) {
                var w = variantRepeater.instances[i];
                if (w)
                    w.visible = true;

            }
            var notifLen = root.notificationItems.length;
            for (var i = 0; i < notifLen; i++) root.notificationItems[i].unread = false
            slide.show = true;
            pollTimer.running = true;
            clockTimer.running = true;
        } else if (!slide.closing) {
            slide.closeAnim();
            pollTimer.running = false;
            clockTimer.running = false;
        }
    }
    Component.onCompleted: {
        refreshNotifications();
        uptimeProc.running = true;
        audioProc.running = true;
        btProc.running = true;
        diagProc.running = true;
    }

    Connections {
        function onNotifListChanged() {
            refreshNotifications();
        }

        target: NotificationState.service
        enabled: NotificationState.service !== null
    }

    Timer {
        id: clockTimer

        interval: 1000
        repeat: true
        running: false
        onTriggered: {
            var now = new Date();
            var hours = now.getHours();
            var ampm = hours >= 12 ? "PM" : "AM";
            hours = hours % 12 || 12;
            root.hourStr = hours.toString().padStart(2, " ");
            root.minStr = now.getMinutes().toString().padStart(2, "0");
            root.secStr = now.getSeconds().toString().padStart(2, "0");
            root.ampmStr = ampm;
            root.timeShort24h = now.getHours().toString().padStart(2, "0") + ":" + root.minStr;
        }
    }

    Process {
        id: uptimeProc

        command: ["uptime", "-p"]
        onExited: function(code) {
            if (code !== 0)
                console.warn("uptimeProc exited with code", code);

        }

        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text)
                    root.uptimeStr = this.text.trim().replace(/^up /i, "");

            }
        }

    }

    Process {
        id: audioProc

        command: [Theme.bin("get_audio_status")]
        onExited: function(code) {
            if (code !== 0)
                console.warn("audioProc exited with code", code);

        }

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var json = JSON.parse(this.text);
                    root.audioMuted = json.muted || false;
                    root.mediaSources = json.media_sources || [];
                    root.currentMediaSource = json.current_media_source || "";
                    var newMedia = json.media || null;
                    root.mediaData = newMedia;
                    if (newMedia && newMedia.art_url) {
                        if (newMedia.art_url.indexOf("http") === 0)
                            root.ensureArtCache(newMedia.art_url);
                        else
                            root.localArtUrl = newMedia.art_url.indexOf("://") !== -1 ? newMedia.art_url : "file://" + newMedia.art_url;
                    } else {
                        root.localArtUrl = "";
                    }
                } catch (e) {
                    console.warn("audioProc parse error:", e);
                }
            }
        }

    }

    FileView {
        path: Theme.cacheDir + "/osd_state.json"
        onDataChanged: {
            if (!audioProc.running)
                audioProc.running = true;

        }
    }

    Process {
        id: diagProc

        command: [Theme.bin("get_sys_diagnostics")]
        onExited: function(code) {
            if (code !== 0)
                console.warn("diagProc exited with code", code);

        }

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var json = JSON.parse(this.text);
                    root.diagCpu = json.cpu && json.cpu.temp != null ? json.cpu.temp.toFixed(0) + "°C" : "";
                    root.diagMem = json.memory && json.memory.used_gb != null ? json.memory.used_gb.toFixed(1) + "/" + json.memory.total_gb.toFixed(1) + " GB" : "";
                    root.diagDisk = json.disk && json.disk.used != null ? json.disk.used + "/" + json.disk.total : "";
                } catch (e) {
                    console.warn("diag parse error:", e);
                }
            }
        }

    }

    // ── Art cache download ──
    ArtCache {
        id: artCache

        cachePrefix: "cpopup_art_"
        onCacheReady: function(url, localPath) {
            if (url === artCache.pendingUrl)
                root.localArtUrl = localPath;

        }
    }

    Process {
        id: ctlProc

        running: false
    }

    Process {
        id: persistPlayerProc

        running: false
    }

    Process {
        id: btProc

        command: [Theme.bin("get_bluetooth_status")]
        onExited: function(code) {
            if (code !== 0)
                console.warn("btProc exited with code", code);

        }

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var json = JSON.parse(this.text);
                    root.btEnabled = json.enabled || false;
                } catch (e) {
                    console.warn("btProc parse error:", e);
                }
            }
        }

    }

    Connections {
        function onNetworkDataChanged() {
            var data = NetworkState.networkData;
            if (data)
                root.wifiEnabled = data.wifi_enabled;

        }

        target: NetworkState
    }

    Timer {
        id: pollTimer

        interval: 30000
        repeat: true
        running: false
        onTriggered: {
            if (!audioProc.running)
                audioProc.running = true;

            if (!btProc.running)
                btProc.running = true;

        }
    }

    SlideAnimator {
        id: slide

        slideFrom: -360
        slideTo: 48
        introDuration: 140
        exitDuration: 120
        onExitCompleted: {
            var instLen = variantRepeater.instances.length;
            for (var i = 0; i < instLen; i++) {
                var w = variantRepeater.instances[i];
                if (w)
                    w.visible = false;

            }
        }
    }

    // ── Popup Windows (per‑screen) ──
    Variants {
        id: variantRepeater

        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: win

                required property var modelData
                property int calendarMonthOffset: 0
                property bool showCalendar: true
                property int selectedNotifIndex: -1

                function selectNext() {
                    var len = root.notificationItems.length;
                    if (len === 0)
                        return ;

                    selectedNotifIndex = Math.min(selectedNotifIndex + 1, len - 1);
                    notifListComp.listView.currentIndex = selectedNotifIndex;
                    notifListComp.listView.positionViewAtIndex(selectedNotifIndex, ListView.Contain);
                }

                function selectPrev() {
                    if (root.notificationItems.length === 0)
                        return ;

                    selectedNotifIndex = Math.max(selectedNotifIndex - 1, 0);
                    notifListComp.listView.currentIndex = selectedNotifIndex;
                    notifListComp.listView.positionViewAtIndex(selectedNotifIndex, ListView.Contain);
                }

                function markAllRead() {
                    var miLen = root.notificationItems.length;
                    for (var i = 0; i < miLen; i++) root.notificationItems[i].unread = false
                }

                visible: false
                onVisibleChanged: {
                    if (visible) {
                        refreshNotifications();
                        root.visibleWindowCount++;
                    } else {
                        root.visibleWindowCount--;
                    }
                }
                screen: modelData
                color: "transparent"
                exclusionMode: PanelWindow.ExclusionMode.Ignore
                focusable: true
                WlrLayershell.namespace: "quickshell-popup"
                implicitWidth: 360
                implicitHeight: Math.min(mainLayout.implicitHeight + 32, 720)

                anchors {
                    top: true
                }

                margins {
                    top: slide.animSlide
                }

                HyprlandFocusGrab {
                    active: win.visible
                    windows: [win]
                    onCleared: {
                        if (root.showPopup)
                            root.closePopup();

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
                        if (event.key === Qt.Key_Escape) {
                            root.closePopup();
                        } else if (event.key === Qt.Key_Down) {
                            win.selectNext();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            win.selectPrev();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                            if (win.selectedNotifIndex >= 0 && win.selectedNotifIndex < root.notificationItems.length) {
                                var n = root.notificationItems[win.selectedNotifIndex];
                                if (n && n.notification) {
                                    if (n.notification.defaultAction)
                                        n.notification.defaultAction.invoke();
                                    else if (n.actions && n.actions.length > 0)
                                        n.actions[0].invoke();
                                }
                            }
                            event.accepted = true;
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

                        // ── Now Playing ──
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.mediaData ? 56 : 0
                            visible: root.mediaData !== null
                            clip: true

                            Rectangle {
                                anchors.fill: parent
                                color: Theme.primaryAlpha005

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 8

                                    Rectangle {
                                        Layout.preferredWidth: 36
                                        Layout.preferredHeight: 36
                                        color: Theme.surface
                                        border.width: 1
                                        border.color: Theme.primaryAlpha02

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
                                            font.pixelSize: Theme.fontSize3xl
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
                                            font.pixelSize: Theme.fontSizeSm
                                            font.bold: true
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: root.mediaData ? root.mediaData.artist || "" : ""
                                            color: Theme.muted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeXs
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }

                                    }

                                    ColumnLayout {
                                        spacing: 4

                                        RowLayout {
                                            spacing: 6
                                            Layout.alignment: Qt.AlignCenter

                                            Text {
                                                text: ""
                                                color: Theme.primary
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSize3xl
                                                visible: root.mediaData && root.mediaData.status === "Playing"

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    hoverEnabled: true
                                                    onClicked: {
                                                        if (root.mediaData && root.mediaData.player) {
                                                            ctlProc.command = ["playerctl", "-p", root.mediaData.player, "previous"];
                                                            ctlProc.running = true;
                                                        }
                                                    }
                                                }

                                            }

                                            Text {
                                                text: root.mediaData && root.mediaData.status === "Playing" ? "" : ""
                                                color: root.mediaData && root.mediaData.status === "Playing" ? Theme.green : Theme.muted
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSize3xl

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    hoverEnabled: true
                                                    onClicked: {
                                                        if (root.mediaData && root.mediaData.player) {
                                                            ctlProc.command = ["playerctl", "-p", root.mediaData.player, "play-pause"];
                                                            ctlProc.running = true;
                                                        }
                                                    }
                                                }

                                            }

                                            Text {
                                                text: ""
                                                color: Theme.primary
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSize3xl
                                                visible: root.mediaData && root.mediaData.status === "Playing"

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    hoverEnabled: true
                                                    onClicked: {
                                                        if (root.mediaData && root.mediaData.player) {
                                                            ctlProc.command = ["playerctl", "-p", root.mediaData.player, "next"];
                                                            ctlProc.running = true;
                                                        }
                                                    }
                                                }

                                            }

                                        }

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: root.currentMediaSource || ""
                                            color: root.mediaSources.length > 1 ? Theme.primary : Theme.muted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeXxs
                                            visible: root.currentMediaSource.length > 0

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                hoverEnabled: true
                                                visible: root.mediaSources.length > 1
                                                onClicked: root.switchPlayer()
                                            }

                                        }

                                    }

                                }

                            }

                        }

                        // ── Active / History Tabs ──
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                Layout.fillWidth: true
                                height: 28
                                color: !root.showHistory ? Theme.primaryAlpha012 : "transparent"
                                radius: 4

                                Text {
                                    anchors.centerIn: parent
                                    text: "Active"
                                    color: !root.showHistory ? Theme.primary : Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeMd
                                    font.bold: !root.showHistory
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.showHistory = false;
                                        root.selectedIds = ({
                                        });
                                        root.refreshNotifications();
                                    }
                                }

                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 28
                                color: root.showHistory ? Theme.primaryAlpha012 : "transparent"
                                radius: 4

                                Text {
                                    anchors.centerIn: parent
                                    text: "History"
                                    color: root.showHistory ? Theme.primary : Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeMd
                                    font.bold: root.showHistory
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.showHistory = true;
                                        root.selectedIds = ({
                                        });
                                        root.refreshNotifications();
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
                                root.showHistory = notifListComp.showHistory;
                                root.selectedIds = ({
                                });
                                root.refreshNotifications();
                            }
                            onSelectedIdsChanged: root.selectedIds = notifListComp.selectedIds
                            onExpandedNotifIdsChanged: root.expandedNotifIds = notifListComp.expandedNotifIds
                            onDismissSelected: (ids) => {
                                if (NotificationState.service) {
                                    NotificationState.service.dismissSelected(ids);
                                    root.selectedIds = ({
                                    });
                                }
                            }
                            onClearAll: {
                                if (NotificationState.service)
                                    NotificationState.service.clearAll();

                            }
                            onClearHistory: {
                                if (NotificationState.service)
                                    NotificationState.service.clearHistory();

                            }
                            onToggleDnd: {
                                if (NotificationState.service)
                                    NotificationState.service.toggleDnd();

                            }
                            onDismissNotification: (id) => {
                                if (NotificationState.service)
                                    NotificationState.service.dismissNotification(id);

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
                                    NetworkState.popup.showPopup = !NetworkState.popup.showPopup;

                            }
                            onMuteToggled: root.audioMuted = !root.audioMuted
                        }

                    }

                }

            }

        }

    }

}
