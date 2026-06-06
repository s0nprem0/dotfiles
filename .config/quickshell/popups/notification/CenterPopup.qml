import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "../.."

Item {
    id: root

    property bool showPopup: false
    property string hourStr: ""
    property string minStr: ""
    property string secStr: ""
    property string ampmStr: ""
    property string uptimeStr: ""
    property int calendarMonthOffset: 0
    property var expandedNotifIds: ({})
    property bool btEnabled: false
    property bool wifiEnabled: false
    property bool audioMuted: false
    property bool glassEnabled: true

    // ─── Clock Timer ────────────────────────────────────────────────
    Timer {
        interval: 1000
        running: true
        repeat: true
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

    // ─── Uptime Process ─────────────────────────────────────────────
    Process {
        id: uptimeProc
        command: ["uptime", "-p"]
        onExited: function(exitCode) {
            if (exitCode === 0 && uptimeProc.stdout.text)
                root.uptimeStr = uptimeProc.stdout.text.trim()
        }
    }
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: { if (!uptimeProc.running) uptimeProc.running = true }
    }

    // ─── Wi‑Fi Status ───────────────────────────────────────────────
    Connections {
        target: NetworkState
        function onNetworkDataChanged() {
            var data = NetworkState.networkData
            if (data) root.wifiEnabled = data.wifi_enabled
        }
    }

    // ─── Audio Muted Status ─────────────────────────────────────────
    Process {
        id: audioProc
        command: [Theme.helperDir + "/get_audio_status"]
        onExited: function(exitCode) {
            if (exitCode === 0 && audioProc.stdout.text) {
                try {
                    var json = JSON.parse(audioProc.stdout.text)
                    root.audioMuted = json.muted || false
                } catch(e) {}
            }
        }
    }
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: { if (!audioProc.running) audioProc.running = true }
    }

    // ─── Bluetooth Status ───────────────────────────────────────────
    Process {
        id: btProc
        command: [Theme.helperDir + "/get_bluetooth_status"]
        onExited: function(exitCode) {
            if (exitCode === 0 && btProc.stdout.text) {
                try {
                    var json = JSON.parse(btProc.stdout.text)
                    root.btEnabled = json.enabled || false
                } catch(e) {}
            }
        }
    }
    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: { if (!btProc.running) btProc.running = true }
    }

    Component.onCompleted: {
        uptimeProc.running = true
        audioProc.running = true
        btProc.running = true
    }

    // ─── Helper Functions ───────────────────────────────────────────
    function closePopup() { root.showPopup = false; }

    function getCalendarDays(offset) {
        var date = new Date();
        date.setMonth(date.getMonth() + offset);
        var year = date.getFullYear();
        var month = date.getMonth();
        var firstDay = new Date(year, month, 1);
        var startDayOfWeek = firstDay.getDay();
        var numDays = new Date(year, month + 1, 0).getDate();
        var numDaysPrev = new Date(year, month, 0).getDate();
        var days = [];
        for (var i = startDayOfWeek - 1; i >= 0; i--)
            days.push({ day: numDaysPrev - i, isCurrentMonth: false, isToday: false });
        var todayDate = new Date();
        for (var d = 1; d <= numDays; d++) {
            var isToday = (todayDate.getDate() === d && todayDate.getMonth() === month && todayDate.getFullYear() === year);
            days.push({ day: d, isCurrentMonth: true, isToday: isToday });
        }
        var remaining = 42 - days.length;
        for (var n = 1; n <= remaining; n++)
            days.push({ day: n, isCurrentMonth: false, isToday: false });
        return days;
    }

    function formatTime(dateObj) {
        if (!dateObj) return "";
        var h = dateObj.getHours().toString().padStart(2, "0");
        var m = dateObj.getMinutes().toString().padStart(2, "0");
        return h + ":" + m;
    }

    // ─── Popup Windows (fixed layout, clock restored) ───────────────
    Variants {
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

                onShowPopupChanged: {
                    if (root.showPopup) {
                        exitAnim.stop()
                        isClosing = false
                        animLeftMargin = -360
                        animOpacity = 0
                        win.visible = true
                        introAnim.start()
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
                implicitHeight: Math.min(mainColumn.implicitHeight + 32, 720)

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
                    active: !win.isClosing
                    windows: [win]
                    onCleared: win.closeAnim()
                }

                Rectangle {
                    anchors.fill: parent
                    opacity: win.animOpacity
                    color: Theme.bg
                    border.width: 1
                    border.color: Theme.primary
                    radius: 0
                    focus: true
                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) win.closeAnim()
                    }
                    Component.onCompleted: forceActiveFocus()

                    Column {
                        id: mainColumn
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 16

                        // ── Row: Calendar + Clock (original layout) ──────────
                        Row {
                            width: parent.width
                            spacing: 20

                            // Calendar column (left)
                            Column {
                                width: 140
                                spacing: 6

                                // Month header with arrows
                                Row {
                                    spacing: 8
                                    Text {
                                        text: {
                                            var date = new Date()
                                            date.setMonth(date.getMonth() + root.calendarMonthOffset)
                                            var months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
                                            return months[date.getMonth()] + " " + date.getFullYear()
                                        }
                                        color: Theme.primary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        font.bold: true
                                    }
                                    Text {
                                        text: ""
                                        color: Theme.primary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.calendarMonthOffset -= 1
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
                                            onClicked: root.calendarMonthOffset += 1
                                        }
                                    }
                                }

                                // Day names
                                Row {
                                    width: parent.width
                                    Repeater {
                                        model: ["S","M","T","W","T","F","S"]
                                        delegate: Text {
                                            width: parent.width / 7
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

                                // Calendar grid
                                Grid {
                                    width: parent.width
                                    columns: 7
                                    rowSpacing: 2
                                    columnSpacing: 0
                                    Repeater {
                                        model: root.getCalendarDays(root.calendarMonthOffset)
                                        delegate: Rectangle {
                                            width: parent.width / 7
                                            height: 18
                                            color: modelData.isToday ? Theme.primary : "transparent"
                                            radius: 0
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

                            // Digital clock column (centered, original style)
                            Column {
                                width: parent.width - 160
                                spacing: 2
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    text: root.hourStr
                                    color: Theme.primary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 28
                                    font.bold: true
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                Text {
                                    text: root.minStr
                                    color: Theme.primary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 24
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                Row {
                                    spacing: 4
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    Text { text: root.secStr; color: Theme.primary; font.family: Theme.fontFamily; font.pixelSize: 11 }
                                    Text { text: root.ampmStr; color: Theme.primary; font.family: Theme.fontFamily; font.pixelSize: 11 }
                                }
                                Item { width: 1; height: 4 }
                                Text {
                                    text: root.uptimeStr.replace("UP ", "")
                                    color: Theme.primary
                                    opacity: 0.75
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.primary
                            opacity: 0.15
                        }

                        // ── Notifications section (scrollable) ──────────────
                        Column {
                            width: parent.width
                            spacing: 8

                            Text {
                                text: "Active"
                                color: Theme.primary
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.bold: true
                                opacity: 0.6
                            }

                            ScrollView {
                                width: parent.width
                                height: Math.min(notifColumn.implicitHeight, 320)
                                clip: true
                                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                                Column {
                                    id: notifColumn
                                    width: parent.width
                                    spacing: 8

                                    Repeater {
                                        model: (NotificationState.server && NotificationState.server.trackedNotifications) ? NotificationState.server.trackedNotifications : []
                                        delegate: Rectangle {
                                            width: parent.width
                                            height: notifContent.implicitHeight + 12
                                            color: Theme.surface
                                            border.width: 1
                                            border.color: modelData.urgency === 2 ? Theme.error : Theme.surfaceLighter
                                            radius: 0

                                            Column {
                                                id: notifContent
                                                anchors.fill: parent
                                                anchors.margins: 8
                                                spacing: 6

                                                Row {
                                                    width: parent.width
                                                    spacing: 10
                                                    Rectangle {
                                                        width: 24; height: 24
                                                        color: "transparent"
                                                        visible: modelData.appIcon && modelData.appIcon.length > 0
                                                        Image {
                                                            anchors.fill: parent
                                                            source: modelData.appIcon.startsWith("/") ? ("file://" + modelData.appIcon) : ("image://icon/" + modelData.appIcon)
                                                            fillMode: Image.PreserveAspectFit
                                                        }
                                                    }
                                                    Column {
                                                        width: parent.width - 34
                                                        spacing: 2
                                                        Text {
                                                            text: modelData.summary
                                                            color: Theme.fg
                                                            font.family: Theme.fontFamily
                                                            font.pixelSize: 10
                                                            font.bold: true
                                                            wrapMode: Text.Wrap
                                                            width: parent.width
                                                        }
                                                        Text {
                                                            text: modelData.timestamp ? formatTime(new Date(modelData.timestamp)) : ""
                                                            color: Theme.muted
                                                            font.family: Theme.fontFamily
                                                            font.pixelSize: 8
                                                        }
                                                    }
                                                    Text {
                                                        text: "✕"
                                                        color: Theme.muted
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 9
                                                        MouseArea {
                                                            anchors.fill: parent
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                if (NotificationState.service && modelData)
                                                                    NotificationState.service.dismissNotification(modelData.id)
                                                            }
                                                        }
                                                    }
                                                }

                                                Text {
                                                    text: modelData.body
                                                    color: Theme.muted
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 9
                                                    wrapMode: Text.Wrap
                                                    width: parent.width
                                                    elide: root.expandedNotifIds[modelData.id] ? Text.ElideNone : Text.ElideRight
                                                    maximumLineCount: root.expandedNotifIds[modelData.id] ? 6 : 2
                                                }

                                                Item {
                                                    width: parent.width; height: 10
                                                    visible: modelData.body.length > 70 || modelData.body.includes("\n")
                                                    Text {
                                                        anchors.right: parent.right
                                                        text: root.expandedNotifIds[modelData.id] ? "less" : "more"
                                                        color: Theme.primary
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 8
                                                        font.bold: true
                                                        MouseArea {
                                                            anchors.fill: parent
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                var copy = Object.assign({}, root.expandedNotifIds)
                                                                copy[modelData.id] = !copy[modelData.id]
                                                                root.expandedNotifIds = copy
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        width: parent.width
                                        text: "No active notifications"
                                        color: Theme.primary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 9
                                        opacity: 0.4
                                        visible: (NotificationState.server && NotificationState.server.trackedNotifications.count === 0) || !NotificationState.server
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.primary
                            opacity: 0.15
                        }

                        // ── Quick action buttons ───────────────────────────
                        RowLayout {
                            width: parent.width
                            spacing: 12

                            Item { width: 28; height: 28; Text { anchors.centerIn: parent; text: root.audioMuted ? "󰝟" : "󰕾"; color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: 16 } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { Quickshell.execDetached(["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"]); root.audioMuted = !root.audioMuted; } } }
                            Item { width: 28; height: 28; Text { anchors.centerIn: parent; text: root.wifiEnabled ? "󰖩" : "󰖪"; color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: 16 } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (NotificationState.networkPopup) NotificationState.networkPopup.showPopup = !NotificationState.networkPopup.showPopup; win.closeAnim() } } }
                            Item { width: 28; height: 28; Text { anchors.centerIn: parent; text: root.btEnabled ? "󰂯" : "󰂲"; color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: 16 } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { Quickshell.execDetached(["bluetoothctl", "power", root.btEnabled ? "off" : "on"]); root.btEnabled = !root.btEnabled; } } }
                            Item { width: 28; height: 28; Text { anchors.centerIn: parent; text: "󰃠"; color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: 16 } MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { Quickshell.execDetached(["brightnessctl", "set", "10%+"]); } } }
                            Item { Layout.fillWidth: true }
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