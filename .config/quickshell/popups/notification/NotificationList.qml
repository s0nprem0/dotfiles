import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "../../service"
import "."

ColumnLayout {
    id: root

    property alias listView: notifListView

    property var notificationItems: []
    property bool showHistory: false
    property var selectedIds: ({})
    property var expandedNotifIds: ({})

    signal dismissSelected(var ids)
    signal clearAll()
    signal clearHistory()
    signal toggleDnd()
    signal dismissNotification(var id)

    spacing: 8

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
                        root.clearHistory()
                    } else {
                        var ids = []
                        for (var k in root.selectedIds) { if (root.selectedIds[k]) ids.push(k) }
                        root.dismissSelected(ids)
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
                onClicked: root.clearAll()
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
                onClicked: root.toggleDnd()
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
                }
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
                width: ListView.view.width
                height: notifContent.implicitHeight + 12
                clip: true
                color: mouseArea.containsMouse ? Qt.alpha(Theme.primary, 0.08) : Theme.surface
                border.width: ListView.isCurrentItem ? 2 : 1
                border.color: ListView.isCurrentItem ? Theme.primary : (modelData.urgency === 2 ? Theme.error : Theme.surfaceLighter)
                radius: 6
                opacity: notif.closed ? 0.5 : 1
                property var notif: modelData

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                }

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
                                                    var icon = IconResolver.resolveDesktopIcon(notif.appIcon)
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
                        Rectangle {
                            width: 20; height: 20
                            radius: 10
                            color: closeMa.containsMouse ? Qt.alpha(Theme.muted, 0.2) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                color: closeMa.containsMouse ? Theme.error : Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                            }

                            MouseArea {
                                id: closeMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.dismissNotification(notif.id)
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
                            delegate: NotificationActionButton {
                                action: modelData
                                btnHeight: 24
                                btnRadius: 3
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
            font.pixelSize: 9
            opacity: 0.4
        }
    }
}
