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
                                    visible: NotificationState.activeNotifs.length > 0

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
                                        onClicked: { if (NotificationState.service) NotificationState.service.toggleDnd() }
                                    }
                                }

                                Text {
                                    text: "Clear"
                                    color: Theme.muted
                                    font.pixelSize: 11
                                    visible: NotificationState.activeNotifs.length > 0 || NotificationState.historyNotifs.length > 0
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (NotificationState.service) NotificationState.service.clearAll();
                                            root.refreshRequested();
                                        }
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
                            height: Math.min(contentHeight + 20, 340)
                            clip: true
                            model: NotificationState.activeNotifs
                            spacing: 6
                            topMargin: 8
                            bottomMargin: 8
                            leftMargin: 8
                            rightMargin: 8

                            delegate: Rectangle {
                                id: notifCard
                                readonly property int notifIndex: index
                                width: notifList.width - 16
                                height: notifBody.implicitHeight + 44 + (actionRow.visible ? 32 : 0)
                                radius: 8
                                color: Theme.surface
                                border.color: mA.containsMouse ? Qt.alpha(Theme.primary, 0.3) : "transparent"
                                border.width: 1
                                clip: true

                                Behavior on border.color { ColorAnimation { duration: 150 } }

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

                                    Rectangle {
                                        width: 32
                                        height: 32
                                        radius: 6
                                        color: Qt.alpha(urgencyColor(model.urgency), 0.15)
                                        Layout.alignment: Qt.AlignTop

                                        Text {
                                            anchors.centerIn: parent
                                            text: {
                                                var icon = modelData.icon || ""
                                                if (icon && icon.length > 0) return ""
                                                var name = modelData.app_name || "N"
                                                return name.charAt(0).toUpperCase()
                                            }
                                            color: urgencyColor(model.urgency)
                                            font.pixelSize: 14
                                            font.bold: true
                                        }

                                        Image {
                                            anchors.fill: parent
                                            source: {
                                                var icon = modelData.icon || ""
                                                if (!icon || icon.length === 0) return ""
                                                if (icon.startsWith("/")) return "file://" + icon
                                                return "image://icon/" + icon
                                            }
                                            fillMode: Image.PreserveAspectFit
                                            asynchronous: true
                                            visible: source.length > 0
                                        }
                                    }

                                    ColumnLayout {
                                        spacing: 2
                                        Layout.fillWidth: true

                                        RowLayout {
                                            spacing: 6
                                            Layout.fillWidth: true

                                            Text {
                                                text: model.app_name || "Notification"
                                                color: Theme.muted
                                                font.pixelSize: 10
                                                font.bold: true
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: formatTime(new Date())
                                                color: Theme.muted
                                                font.pixelSize: 9
                                                opacity: 0.6
                                            }
                                        }

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

                                        Text {
                                            id: notifBody
                                            text: model.body
                                            color: Qt.alpha(Theme.fg, 0.7)
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                            wrapMode: Text.Wrap
                                            maximumLineCount: root.expandedNotifIds[model.id] ? 99 : 3
                                            visible: text.length > 0
                                            Layout.fillWidth: true
                                        }

                                        Item {
                                            width: parent.width
                                            height: 10
                                            visible: model.body.length > 60 || (model.body.includes("\n") && !root.expandedNotifIds[model.id])

                                            Text {
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: root.expandedNotifIds[model.id] ? "show less" : "show more"
                                                color: Theme.primary
                                                font.pixelSize: 9
                                                font.bold: true
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        var copy = Object.assign({}, root.expandedNotifIds);
                                                        copy[model.id] = !copy[model.id];
                                                        root.expandedNotifIds = copy;
                                                    }
                                                }
                                            }
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
                                                            if (NotificationState.service) {
                                                                NotificationState.service.dismissNotification(notifCard.notifIndex)
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
                                                if (NotificationState.service) {
                                                    NotificationState.service.dismissNotification(notifCard.notifIndex)
                                                }
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
                                visible: notifList.count === 0 && NotificationState.historyNotifs.length === 0

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

                        // ── History Section ─────────────────────────────
                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.surfaceLighter
                        }

                        Column {
                            width: parent.width
                            spacing: 4
                            visible: NotificationState.historyNotifs.length > 0

                            Rectangle {
                                width: parent.width
                                height: 28
                                color: "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 10
                                    spacing: 8

                                    Text {
                                        text: NotificationState.historyExpanded ? "" : ""
                                        color: Theme.muted
                                        font.pixelSize: 8
                                        font.bold: true
                                        opacity: 0.6
                                    }

                                    Text {
                                        text: "History"
                                        color: Theme.muted
                                        font.pixelSize: 8
                                        font.bold: true
                                        opacity: 0.6
                                    }

                                    Text {
                                        text: "Restore Last"
                                        color: Theme.primary
                                        font.pixelSize: 8
                                        font.bold: true
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                Quickshell.execDetached(["makoctl", "restore"])
                                                root.refreshRequested()
                                            }
                                        }
                                    }

                                    Item { Layout.fillWidth: true }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        NotificationState.historyExpanded = !NotificationState.historyExpanded
                                    }
                                }
                            }

                            Column {
                                width: parent.width
                                spacing: 4
                                visible: NotificationState.historyExpanded

                                Repeater {
                                    model: NotificationState.historyNotifs

                                    delegate: Rectangle {
                                        width: parent.width - 16
                                        height: histBoxCol.implicitHeight + 10
                                        color: Theme.surface
                                        border.width: 1
                                        border.color: Theme.surfaceLighter
                                        radius: 6
                                        anchors.horizontalCenter: parent.horizontalCenter

                                        Column {
                                            id: histBoxCol
                                            anchors.top: parent.top
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.margins: 8
                                            spacing: 3

                                            Row {
                                                width: parent.width
                                                spacing: 8

                                                Text {
                                                    text: model.app_name ? model.app_name.charAt(0).toUpperCase() : "N"
                                                    color: Theme.muted
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                }

                                                Column {
                                                    width: parent.width - 20
                                                    spacing: 1

                                                    Text {
                                                        text: model.summary
                                                        color: Theme.fg
                                                        font.pixelSize: 10
                                                        font.bold: true
                                                        elide: Text.ElideRight
                                                        width: parent.width
                                                    }

                                                    Text {
                                                        text: model.body
                                                        color: Qt.alpha(Theme.fg, 0.6)
                                                        font.pixelSize: 9
                                                        wrapMode: Text.Wrap
                                                        width: parent.width
                                                        maximumLineCount: root.expandedNotifIds[model.id + "_hist"] ? 99 : 2
                                                        elide: root.expandedNotifIds[model.id + "_hist"] ? Text.ElideNone : Text.ElideRight
                                                    }
                                                }
                                            }

                                            Item {
                                                width: parent.width
                                                height: 10
                                                visible: model.body.length > 40 || model.body.includes("\n")

                                                Text {
                                                    anchors.right: parent.right
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: root.expandedNotifIds[model.id + "_hist"] ? "show less" : "show more"
                                                    color: Theme.primary
                                                    font.pixelSize: 8
                                                    font.bold: true
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            var copy = Object.assign({}, root.expandedNotifIds);
                                                            copy[model.id + "_hist"] = !copy[model.id + "_hist"];
                                                            root.expandedNotifIds = copy;
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ── Quick Launcher Buttons ──────────────────────
                        Rectangle {
                            width: parent.width
                            height: 36
                            color: Theme.surface

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 0

                                Item {
                                    width: parent.width / 6
                                    height: 14

                                    Text {
                                        id: btnVol
                                        anchors.centerIn: parent
                                        text: "󰕾"
                                        color: Theme.muted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onEntered: btnVol.color = Theme.fg
                                        onExited: btnVol.color = Theme.muted
                                        onClicked: {
                                            Quickshell.execDetached(["quickshell", "--config", "volume_popup"])
                                            win.closeAnim()
                                        }
                                    }
                                }

                                Item {
                                    width: parent.width / 6
                                    height: 14

                                    Text {
                                        id: btnNet
                                        anchors.centerIn: parent
                                        text: "󰖩"
                                        color: Theme.muted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onEntered: btnNet.color = Theme.fg
                                        onExited: btnNet.color = Theme.muted
                                        onClicked: {
                                            Quickshell.execDetached(["quickshell", "--config", "network_popup"])
                                            win.closeAnim()
                                        }
                                    }
                                }

                                Item {
                                    width: parent.width / 6
                                    height: 14

                                    Text {
                                        id: btnBt
                                        anchors.centerIn: parent
                                        text: "󰂯"
                                        color: Theme.muted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onEntered: btnBt.color = Theme.fg
                                        onExited: btnBt.color = Theme.muted
                                        onClicked: {
                                            Quickshell.execDetached(["quickshell", "--config", "bluetooth_popup"])
                                            win.closeAnim()
                                        }
                                    }
                                }

                                Item {
                                    width: parent.width / 6
                                    height: 14

                                    Text {
                                        id: btnBright
                                        anchors.centerIn: parent
                                        text: "󰃠"
                                        color: Theme.muted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onEntered: btnBright.color = Theme.fg
                                        onExited: btnBright.color = Theme.muted
                                        onClicked: {
                                            Quickshell.execDetached(["quickshell", "--config", "brightness_popup"])
                                            win.closeAnim()
                                        }
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: formatTime(new Date())
                                    color: Theme.muted
                                    font.pixelSize: 12
                                    font.bold: true
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
