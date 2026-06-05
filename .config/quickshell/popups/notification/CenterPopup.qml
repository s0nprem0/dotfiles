import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import "../.."

Scope {
    id: root

    property bool showPopup: false

    signal refreshRequested()

    function closePopup() {
        root.showPopup = false;
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

    function formatDate(dateObj) {
        if (!dateObj) return "";
        var now = new Date();
        var diff = now - dateObj;
        if (diff < 60000) return "just now";
        if (diff < 3600000) return Math.floor(diff / 60000) + "m ago";
        if (diff < 86400000) return Math.floor(diff / 3600000) + "h ago";
        return dateObj.toLocaleDateString();
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: win
                required property var modelData
                visible: false

                property bool isClosing: false
                property real animRightMargin: -420
                property real animOpacity: 0
                property real animHeaderY: -60
                property bool showPopup: root.showPopup

                onShowPopupChanged: {
                    if (root.showPopup) {
                        exitAnim.stop();
                        isClosing = false;
                        animRightMargin = -420;
                        animOpacity = 0;
                        animHeaderY = -60;
                        root.refreshRequested();
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
                    exitAnim.start();
                }

                screen: modelData
                color: "transparent"
                exclusionMode: PanelWindow.ExclusionMode.Ignore
                focusable: true
                implicitWidth: 380
                implicitHeight: Math.min(mainColumn.implicitHeight, 520)

                Component.onCompleted: { root.refreshRequested(); }

                anchors {
                    top: true
                    right: true
                }

                margins {
                    top: 40
                    right: win.animRightMargin
                }

                ParallelAnimation {
                    id: introAnim
                    NumberAnimation { target: win; property: "animRightMargin"; from: -420; to: 8; duration: 150; easing.type: Easing.OutCubic }
                    NumberAnimation { target: win; property: "animOpacity"; from: 0; to: 1; duration: 150; easing.type: Easing.OutCubic }
                    NumberAnimation { target: win; property: "animHeaderY"; from: -60; to: 0; duration: 150; easing.type: Easing.OutCubic }
                }

                ParallelAnimation {
                    id: exitAnim
                    onStopped: {
                        win.visible = false;
                        root.showPopup = false;
                    }
                    NumberAnimation { target: win; property: "animRightMargin"; from: 8; to: -420; duration: 120; easing.type: Easing.InCubic }
                    NumberAnimation { target: win; property: "animOpacity"; from: 1; to: 0; duration: 120; easing.type: Easing.InCubic }
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
                    border.color: Theme.surfaceLighter
                    radius: 10
                    clip: true
                    focus: true
                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) win.closeAnim();
                    }
                    Component.onCompleted: { forceActiveFocus(); }

                    Column {
                        id: mainColumn
                        anchors.fill: parent
                        spacing: 0

                        // ── Header ────────────────────────────────────────
                        Rectangle {
                            width: parent.width
                            height: 44
                            color: Theme.surface
                            transform: Translate { y: win.animHeaderY }
                            Behavior on color { ColorAnimation { duration: 200 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 10
                                spacing: 8

                                Text {
                                    text: "Notifications"
                                    color: Theme.fg
                                    font.pixelSize: 14
                                    font.bold: true
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    id: dndBtn
                                    height: 24
                                    width: dndLabel.implicitWidth + 16
                                    radius: 12
                                    color: NotificationState.dnd ? Theme.error : "transparent"
                                    border.color: NotificationState.dnd ? "transparent" : Theme.surfaceLighter
                                    border.width: 1
                                    visible: NotificationState.server && NotificationState.server.trackedNotifications.count > 0

                                    Behavior on color { ColorAnimation { duration: 200 } }

                                    Text {
                                        id: dndLabel
                                        anchors.centerIn: parent
                                        text: "DND"
                                        color: NotificationState.dnd ? Theme.bg : Theme.muted
                                        font.pixelSize: 10
                                        font.bold: true
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: NotificationState.service.toggleDnd()
                                    }
                                }

                                Text {
                                    text: "Clear"
                                    color: Theme.muted
                                    font.pixelSize: 11
                                    visible: NotificationState.server && NotificationState.server.trackedNotifications.count > 0
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: NotificationState.service.clearAll()
                                    }
                                }

                                Text {
                                    text: "✕"
                                    color: Theme.fg
                                    font.pixelSize: 14
                                    font.bold: true
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: win.closeAnim()
                                    }
                                }
                            }
                        }

                        // DND banner
                        Rectangle {
                            width: parent.width
                            height: dndActive ? 28 : 0
                            color: Qt.alpha(Theme.error, 0.1)
                            visible: dndActive
                            clip: true

                            readonly property bool dndActive: NotificationState.dnd

                            Text {
                                anchors.centerIn: parent
                                text: "Do Not Disturb — notifications are being silenced"
                                color: Theme.error
                                font.pixelSize: 10
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.surfaceLighter
                        }

                        // ── Notification List ─────────────────────────────
                        ListView {
                            id: notifList
                            width: parent.width
                            height: Math.min(contentHeight, 440)
                            clip: true
                            model: NotificationState.server ? NotificationState.server.trackedNotifications : null
                            spacing: 6
                            topMargin: 8
                            bottomMargin: 8
                            leftMargin: 8
                            rightMargin: 8

                            delegate: Rectangle {
                                id: notifCard
                                width: notifList.width - 16
                                height: notifBody.implicitHeight + 44 + (actionRow.visible ? 32 : 0)
                                radius: 8
                                color: Theme.surface
                                border.color: mA.containsMouse ? Qt.alpha(Theme.primary, 0.3) : "transparent"
                                border.width: 1
                                clip: true

                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                // Urgency left border
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: 3
                                    radius: 2
                                    color: urgencyColor(model.urgency)
                                    anchors.topMargin: 6
                                    anchors.bottomMargin: 6
                                    anchors.leftMargin: 3
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 10
                                    anchors.topMargin: 10
                                    anchors.bottomMargin: 10
                                    spacing: 10

                                    // App icon
                                    Rectangle {
                                        width: 32
                                        height: 32
                                        radius: 6
                                        color: Qt.alpha(urgencyColor(model.urgency), 0.15)
                                        Layout.alignment: Qt.AlignTop

                                        Text {
                                            anchors.centerIn: parent
                                            text: model.appName ? model.appName.charAt(0).toUpperCase() : "N"
                                            color: urgencyColor(model.urgency)
                                            font.pixelSize: 14
                                            font.bold: true
                                        }
                                    }

                                    ColumnLayout {
                                        spacing: 2
                                        Layout.fillWidth: true

                                        // App name + time
                                        RowLayout {
                                            spacing: 6
                                            Layout.fillWidth: true

                                            Text {
                                                text: model.appName || "Notification"
                                                color: Theme.muted
                                                font.pixelSize: 10
                                                font.bold: true
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: formatTime(model.timestamp)
                                                color: Theme.muted
                                                font.pixelSize: 9
                                                opacity: 0.6
                                            }
                                        }

                                        // Summary
                                        Text {
                                            id: notifSummary
                                            text: model.summary
                                            color: Theme.fg
                                            font.pixelSize: 12
                                            font.bold: true
                                            elide: Text.ElideRight
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 2
                                            Layout.fillWidth: true
                                        }

                                        // Body
                                        Text {
                                            id: notifBody
                                            text: model.body
                                            color: Qt.alpha(Theme.fg, 0.7)
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 3
                                            visible: text.length > 0
                                            Layout.fillWidth: true
                                        }

                                        // Action buttons
                                        Row {
                                            id: actionRow
                                            spacing: 6
                                            visible: model.actions && model.actions.length > 0
                                            Layout.topMargin: 4

                                            Repeater {
                                                model: model.actions || []

                                                Rectangle {
                                                    height: 22
                                                    width: actionLabel.implicitWidth + 12
                                                    radius: 4
                                                    color: Qt.alpha(Theme.primary, 0.1)
                                                    border.color: Qt.alpha(Theme.primary, 0.3)
                                                    border.width: 1

                                                    Text {
                                                        id: actionLabel
                                                        anchors.centerIn: parent
                                                        text: modelData || ""
                                                        color: Theme.primary
                                                        font.pixelSize: 10
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            var notif = notifList.model.get(index);
                                                            if (notif && notif.invokeAction) {
                                                                notif.invokeAction(model.index);
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Dismiss
                                    Text {
                                        text: "✕"
                                        color: Theme.muted
                                        font.pixelSize: 12
                                        Layout.alignment: Qt.AlignTop
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var notif = notifList.model.get(index);
                                                if (notif) notif.dismiss();
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: mA
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton
                                }
                            }

                            // Empty state
                            Item {
                                anchors.centerIn: parent
                                width: parent.width - 32
                                visible: notifList.count === 0

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 8

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "󰂜"
                                        color: Theme.muted
                                        font.pixelSize: 32
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "No notifications"
                                        color: Theme.muted
                                        font.pixelSize: 13
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "You're all caught up"
                                        color: Qt.alpha(Theme.muted, 0.6)
                                        font.pixelSize: 11
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "notification_center"
        function close() {
            root.closePopup();
        }
    }
}
