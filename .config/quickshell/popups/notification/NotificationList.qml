import "."
import "../../service"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

ColumnLayout {
    id: root

    property alias listView: notifListView
    property var notificationItems: []
    property bool showHistory: false
    property var selectedIds: ({
    })
    property var expandedNotifIds: ({
    })

    signal dismissSelected(var ids)
    signal clearAll()
    signal clearHistory()
    signal toggleDnd()
    signal dismissNotification(var id)

    function selectionCount() {
        var count = 0;
        for (var k in root.selectedIds) {
            if (root.selectedIds[k])
                count++;

        }
        return count;
    }

    function toggleSelectAll() {
        var all = true;
        var niLen = root.notificationItems.length;
        for (var i = 0; i < niLen; i++) {
            if (!root.selectedIds[root.notificationItems[i].id]) {
                all = false;
                break;
            }
        }
        var newSel = {
        };
        if (!all) {
            for (var j = 0; j < root.notificationItems.length; j++) newSel[root.notificationItems[j].id] = true
        }
        root.selectedIds = newSel;
    }

    spacing: 8

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Item {
            Layout.fillWidth: true
        }

        Text {
            text: root.showHistory ? "Clear" : "Dismiss Selected (" + root.selectionCount() + ")"
            color: root.selectionCount() > 0 ? Theme.error : Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSm
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
                        root.clearHistory();
                    } else {
                        var ids = [];
                        for (var k in root.selectedIds) {
                            if (root.selectedIds[k])
                                ids.push(k);

                        }
                        root.dismissSelected(ids);
                        root.selectedIds = ({
                        });
                    }
                }
            }

        }

        Text {
            text: root.selectionCount() > 0 && root.selectionCount() < root.notificationItems.length ? "Select All" : "Select None"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSm
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
            font.pixelSize: Theme.fontSizeSm
            visible: !root.showHistory && root.selectionCount() === 0 && root.notificationItems.length > 0

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onEntered: parent.color = Theme.primary
                onExited: parent.color = Theme.muted
                onClicked: root.clearAll()
            }

        }

        Text {
            text: "🔇 DND"
            color: Theme.error
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSm
            font.bold: true
            visible: NotificationState.dnd

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onEntered: parent.color = Qt.lighter(Theme.error, 1.2)
                onExited: parent.color = Theme.error
                onClicked: root.toggleDnd()
            }

        }

    }

    ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: root.notificationItems.length > 0
        Layout.minimumHeight: root.notificationItems.length > 0 ? 100 : 0
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
                property var notif: modelData

                width: ListView.view.width
                height: notifContent.implicitHeight + 12
                clip: true
                color: mouseArea.containsMouse ? Theme.primaryAlpha008 : Theme.surface
                border.width: 0
                border.color: ListView.isCurrentItem ? Theme.primary : (modelData.urgency === 2 ? Theme.error : Theme.surfaceLighter)
                radius: 0
                opacity: notif.closed ? 0.5 : 1

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 4
                    color: notif.urgency === 2 ? Theme.error : notif.unread ? Theme.primary : Theme.surfaceLighter
                }

                MouseArea {
                    id: mouseArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                }

                ColumnLayout {
                    id: notifContent

                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8
                    anchors.topMargin: 8
                    anchors.bottomMargin: 8
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle {
                            width: 12
                            height: 12
                            color: root.selectedIds[notif.id] ? Theme.primary : "transparent"
                            radius: 0
                            border.width: root.selectedIds[notif.id] ? 0 : 1
                            border.color: Theme.muted
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !root.showHistory

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var newSel = {
                                    };
                                    for (var k in root.selectedIds) newSel[k] = root.selectedIds[k]
                                    if (newSel[notif.id])
                                        delete newSel[notif.id];
                                    else
                                        newSel[notif.id] = true;
                                    root.selectedIds = newSel;
                                }
                            }

                        }

                        Rectangle {
                            width: 32
                            height: 32
                            color: "transparent"
                            visible: notif.appIcon && notif.appIcon.length > 0

                            Image {
                                anchors.fill: parent
                                source: {
                                    var icon = IconResolver.resolveDesktopIcon(notif.appIcon);
                                    if (icon)
                                        return "image://icon/" + icon;

                                    if (notif.appIcon.startsWith("/"))
                                        return "file://" + notif.appIcon;

                                    return "image://icon/" + notif.appIcon;
                                }
                                fillMode: Image.PreserveAspectFit
                            }

                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                visible: (notif.appName || "").length > 0

                                Text {
                                    Layout.fillWidth: true
                                    text: notif.appName || ""
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: "󰃁"
                                    color: Theme.primary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    visible: notif.expireTimeout === 0
                                }

                            }

                            Text {
                                text: notif.summary
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeMd
                                font.bold: true
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }

                            Text {
                                text: notif.timeStr || ""
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeXxs
                                Layout.alignment: Qt.AlignTop
                            }

                        }

                        Rectangle {
                            width: 20
                            height: 20
                            radius: 0
                            color: closeMa.containsMouse ? Qt.alpha(Theme.muted, 0.2) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                color: closeMa.containsMouse ? Theme.error : Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeMd
                            }

                            MouseArea {
                                id: closeMa

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.dismissNotification(notif.id)
                            }

                        }

                        Rectangle {
                            width: 20
                            height: 20
                            radius: 0
                            color: snoozeMa.containsMouse ? Qt.alpha(Theme.muted, 0.2) : "transparent"
                            visible: !root.showHistory

                            Text {
                                anchors.centerIn: parent
                                text: "⏰"
                                color: snoozeMa.containsMouse ? Theme.primary : Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeMd
                            }

                            MouseArea {
                                id: snoozeMa

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var n = notif;
                                    n.snooze(30 * 60 * 1000);
                                }
                            }

                        }

                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Item {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignTop

                            Text {
                                text: notif.body
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                                textFormat: Text.StyledText
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                                elide: root.expandedNotifIds[notif.id] ? Text.ElideNone : Text.ElideRight
                                maximumLineCount: root.expandedNotifIds[notif.id] ? 99 : 2
                                onLinkActivated: (link) => {
                                    return Qt.openUrlExternally(link);
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 80
                                Layout.preferredHeight: 80
                                visible: notif.image && notif.image.length > 0
                                color: "transparent"
                                border.width: 1
                                border.color: Theme.primary

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    fillMode: Image.PreserveAspectCrop
                                    clip: true
                                    source: notif.image ? (notif.image.startsWith("/") ? ("file://" + notif.image) : notif.image) : ""
                                }

                            }

                        }

                    }

                    // ─── Progress Bar ──────────────────────────
                    Rectangle {
                        Layout.fillWidth: true
                        height: 4
                        radius: 0
                        color: Theme.primaryAlpha01
                        visible: notif.hints && notif.hints.value !== undefined

                        Rectangle {
                            width: parent.width * Math.min(1, Math.max(0, (notif.hints.value / (notif.hints.maximum || 100))))
                            height: parent.height
                            radius: 0
                            color: Theme.primary
                        }

                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        visible: notif.actions && notif.actions.length > 0

                        Repeater {
                            model: notif.actions

                            delegate: NotificationActionButton {
                                action: modelData
                                btnHeight: 24
                                btnRadius: 0
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
                            font.pixelSize: Theme.fontSizeXs
                            font.bold: true

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: parent.color = Qt.lighter(Theme.primary, 1.2)
                                onExited: parent.color = Theme.primary
                                onClicked: {
                                    var newState = {
                                    };
                                    for (var k in root.expandedNotifIds) newState[k] = root.expandedNotifIds[k]
                                    newState[notif.id] = !newState[notif.id];
                                    root.expandedNotifIds = newState;
                                }
                            }

                        }

                    }

                }

            }

        }

    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: root.notificationItems.length === 0
        visible: root.notificationItems.length === 0

        Text {
            anchors.centerIn: parent
            text: root.showHistory ? "No history" : "No notifications"
            color: Theme.primary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSm
            opacity: 0.4
        }

    }

}
