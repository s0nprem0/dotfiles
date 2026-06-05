import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import "../.."

Scope {
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

    function closePopup() {
        root.showPopup = false;
    }

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
        for (var i = startDayOfWeek - 1; i >= 0; i--) {
            days.push({ "day": numDaysPrev - i, "isCurrentMonth": false, "isToday": false });
        }
        var todayDate = new Date();
        for (var d = 1; d <= numDays; d++) {
            var isToday = (todayDate.getDate() === d && todayDate.getMonth() === month && todayDate.getFullYear() === year);
            days.push({ "day": d, "isCurrentMonth": true, "isToday": isToday });
        }
        var remaining = 42 - days.length;
        for (var n = 1; n <= remaining; n++) {
            days.push({ "day": n, "isCurrentMonth": false, "isToday": false });
        }
        return days;
    }

    function urgencyColor(urgency) {
        if (urgency === 2) return Theme.error;
        if (urgency === 1) return Theme.primary;
        return Theme.muted;
    }

    function formatTime(dateObj) {
        if (!dateObj) return "";
        var h = dateObj.getHours().toString().padStart(2, "0");
        var m = dateObj.getMinutes().toString().padStart(2, "0");
        return h + ":" + m;
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: win
                required property var modelData
                visible: false

                property bool isClosing: false
                property real animLeftMargin: -260
                property real animOpacity: 0
                property bool showPopup: root.showPopup

                onShowPopupChanged: {
                    if (root.showPopup) {
                        exitAnim.stop();
                        isClosing = false;
                        animLeftMargin = -260;
                        animOpacity = 0;
                        win.visible = true;
                        introAnim.start();
                    } else if (!isClosing) {
                        introAnim.stop();
                        closeAnim();
                    }
                }

                function closeAnim() {
                    if (isClosing) return;
                    isClosing = true;
                    root.showPopup = false;
                    exitAnim.start();
                }

                screen: modelData
                color: "transparent"
                exclusionMode: PanelWindow.ExclusionMode.Ignore
                focusable: true
                implicitWidth: 240
                implicitHeight: Math.min(mainLayout.implicitHeight + 20, 520)

                anchors { left: true }
                margins { left: win.animLeftMargin }

                ParallelAnimation {
                    id: introAnim
                    NumberAnimation { target: win; property: "animLeftMargin"; from: -260; to: 32; duration: 120; easing.type: Easing.OutCubic }
                    NumberAnimation { target: win; property: "animOpacity"; from: 0; to: 1; duration: 120; easing.type: Easing.OutCubic }
                }

                ParallelAnimation {
                    id: exitAnim
                    onStopped: { win.visible = false; }
                    NumberAnimation { target: win; property: "animLeftMargin"; from: 32; to: -260; duration: 100; easing.type: Easing.InCubic }
                    NumberAnimation { target: win; property: "animOpacity"; from: 1; to: 0; duration: 100; easing.type: Easing.InCubic }
                }

                HyprlandFocusGrab {
                    active: !win.isClosing
                    windows: [win]
                    onCleared: { win.closeAnim(); }
                }

                Rectangle {
                    anchors.fill: parent
                    opacity: win.animOpacity
                    color: Theme.bg
                    border.width: 1
                    border.color: Theme.primary
                    radius: 0
                    antialiasing: false
                    focus: true
                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) win.closeAnim();
                    }
                    Component.onCompleted: { forceActiveFocus(); }

                    Column {
                        id: mainLayout
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 10
                        spacing: 10

                        // ── Clock + Calendar ─────────────────────────────────
                        Row {
                            width: parent.width
                            spacing: 10

                            Item {
                                id: calendarWrapper
                                width: 120
                                height: calCol.implicitHeight

                                Column {
                                    id: calCol
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    width: 110
                                    spacing: 2

                                    Text {
                                        text: {
                                            var date = new Date();
                                            date.setMonth(date.getMonth() + root.calendarMonthOffset);
                                            var months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
                                            return months[date.getMonth()] + " " + date.getFullYear();
                                        }
                                        color: Theme.primary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 8
                                        font.bold: true
                                        opacity: 0.8
                                        renderType: Text.NativeRendering
                                    }

                                    Row {
                                        width: parent.width
                                        Repeater {
                                            model: ["S","M","T","W","T","F","S"]
                                            delegate: Item {
                                                width: parent.width / 7
                                                height: 10
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData
                                                    color: Theme.primary
                                                    opacity: 0.5
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 6
                                                    font.bold: true
                                                    renderType: Text.NativeRendering
                                                }
                                            }
                                        }
                                    }

                                    Grid {
                                        width: parent.width
                                        columns: 7
                                        rowSpacing: 1
                                        columnSpacing: 0
                                        Repeater {
                                            model: root.getCalendarDays(root.calendarMonthOffset)
                                            delegate: Rectangle {
                                                width: parent.width / 7
                                                height: 11
                                                color: modelData.isToday ? Theme.primary : "transparent"
                                                radius: 1
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: String(modelData.day)
                                                    color: modelData.isToday ? Theme.bg : Theme.primary
                                                    opacity: modelData.isToday ? 1 : (modelData.isCurrentMonth ? 0.85 : 0.25)
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 6
                                                    font.bold: modelData.isToday
                                                    renderType: Text.NativeRendering
                                                }
                                            }
                                        }
                                    }
                                }

                                Text {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    text: ""
                                    color: Theme.primary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 7
                                    opacity: 0.6
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.calendarMonthOffset -= 1
                                    }
                                }

                                Text {
                                    anchors.bottom: parent.bottom
                                    anchors.right: parent.right
                                    text: ""
                                    color: Theme.primary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 7
                                    opacity: 0.6
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.calendarMonthOffset += 1
                                    }
                                }
                            }

                            Column {
                                width: parent.width - 130
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1

                                Text {
                                    text: root.hourStr
                                    color: Theme.primary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 18
                                    font.bold: true
                                    renderType: Text.NativeRendering
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                Text {
                                    text: root.minStr
                                    color: Theme.primary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 18
                                    renderType: Text.NativeRendering
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 2
                                    Text {
                                        text: root.secStr
                                        color: Theme.primary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 8
                                        renderType: Text.NativeRendering
                                    }
                                    Text {
                                        text: root.ampmStr
                                        color: Theme.primary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 8
                                        renderType: Text.NativeRendering
                                    }
                                }

                                Item { width: 1; height: 4 }

                                Text {
                                    text: root.uptimeStr.replace("UP ", "")
                                    color: Theme.primary
                                    opacity: 0.75
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering
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

                        // ── Active Notifications ─────────────────────────────
                        Column {
                            width: parent.width
                            spacing: 4

                            Text {
                                text: "Active"
                                color: Theme.primary
                                font.family: Theme.fontFamily
                                font.pixelSize: 7
                                font.bold: true
                                opacity: 0.6
                                renderType: Text.NativeRendering
                            }

                            Text {
                                text: "No active notifications"
                                color: Theme.primary
                                font.family: Theme.fontFamily
                                font.pixelSize: 7
                                opacity: 0.4
                                visible: !NotificationState.server || NotificationState.server.trackedNotifications.count === 0
                            }

                            Repeater {
                                model: NotificationState.server ? NotificationState.server.trackedNotifications : []

                                delegate: Rectangle {
                                    width: parent.width
                                    height: activeBoxCol.implicitHeight + 8
                                    color: Theme.surface
                                    border.width: 1
                                    border.color: modelData.urgency === 2 ? Theme.error : Theme.surfaceLighter
                                    radius: 4

                                    Column {
                                        id: activeBoxCol
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.margins: 4
                                        spacing: 2

                                        Row {
                                            width: parent.width
                                            spacing: 6

                                            Rectangle {
                                                width: 16
                                                height: 16
                                                color: "transparent"
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: modelData.appIcon && modelData.appIcon.length > 0

                                                Image {
                                                    anchors.fill: parent
                                                    source: modelData.appIcon.startsWith("/") ? ("file://" + modelData.appIcon) : ("image://icon/" + modelData.appIcon)
                                                    fillMode: Image.PreserveAspectFit
                                                    asynchronous: true
                                                }
                                            }

                                            Column {
                                                width: parent.width - (modelData.appIcon && modelData.appIcon.length > 0 ? 24 : 0)
                                                spacing: 1
                                                anchors.verticalCenter: parent.verticalCenter

                                                Item {
                                                    width: parent.width
                                                    height: 12

                                                    Text {
                                                        text: modelData.summary
                                                        color: Theme.fg
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 7
                                                        font.bold: true
                                                        elide: Text.ElideRight
                                                        anchors.left: parent.left
                                                        anchors.right: dismissBtn.left
                                                        anchors.rightMargin: 4
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        renderType: Text.NativeRendering
                                                    }

                                                    Text {
                                                        id: dismissBtn
                                                        anchors.right: parent.right
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: "dismiss"
                                                        color: Theme.primary
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 7
                                                        renderType: Text.NativeRendering
                                                        MouseArea {
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            onClicked: {
                                                                if (NotificationState.service && modelData)
                                                                    NotificationState.service.dismissNotification(modelData.id);
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            id: descText
                                            text: modelData.body
                                            color: Theme.muted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 7
                                            wrapMode: Text.Wrap
                                            width: parent.width
                                            elide: root.expandedNotifIds[modelData.id] ? Text.ElideNone : Text.ElideRight
                                            maximumLineCount: root.expandedNotifIds[modelData.id] ? 99 : 1
                                            renderType: Text.NativeRendering
                                        }

                                        Item {
                                            width: parent.width
                                            height: 8
                                            visible: modelData.body.length > 50 || modelData.body.includes("\n")

                                            Text {
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: root.expandedNotifIds[modelData.id] ? "show less" : "show more"
                                                color: Theme.primary
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 6
                                                font.bold: true
                                                renderType: Text.NativeRendering
                                                MouseArea {
                                                    anchors.fill: parent
                                                    onClicked: {
                                                        var copy = Object.assign({}, root.expandedNotifIds);
                                                        copy[modelData.id] = !copy[modelData.id];
                                                        root.expandedNotifIds = copy;
                                                    }
                                                }
                                            }
                                        }
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

                        // ── Quick Launcher Buttons ──────────────────────────
                        Row {
                            width: parent.width
                            spacing: 0

                            Item {
                                width: parent.width / 6
                                height: 12

                                Text {
                                    id: btnVol
                                    anchors.centerIn: parent
                                    text: root.audioMuted ? "󰝟" : "󰕾"
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        Quickshell.execDetached(["quickshell", "--config", "volume_popup"]);
                                        win.closeAnim();
                                    }
                                }
                            }

                            Item {
                                width: parent.width / 6
                                height: 12

                                Text {
                                    id: btnNet
                                    anchors.centerIn: parent
                                    text: root.wifiEnabled ? "󰖩" : "󰖪"
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        Quickshell.execDetached(["quickshell", "--config", "network_popup"]);
                                        win.closeAnim();
                                    }
                                }
                            }

                            Item {
                                width: parent.width / 6
                                height: 12

                                Text {
                                    id: btnBt
                                    anchors.centerIn: parent
                                    text: root.btEnabled ? "󰂯" : "󰂲"
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        Quickshell.execDetached(["quickshell", "--config", "bluetooth_popup"]);
                                        win.closeAnim();
                                    }
                                }
                            }

                            Item {
                                width: parent.width / 6
                                height: 12

                                Text {
                                    id: btnBright
                                    anchors.centerIn: parent
                                    text: "󰃠"
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        Quickshell.execDetached(["quickshell", "--config", "brightness_popup"]);
                                        win.closeAnim();
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: formatTime(new Date())
                                color: Theme.primary
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.bold: true
                                renderType: Text.NativeRendering
                            }
                        }
                    }
                }
            }
        }
    }
}