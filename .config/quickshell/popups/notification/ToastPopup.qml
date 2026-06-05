import Quickshell
import QtQuick
import QtQuick.Layouts

import "../.."

PanelWindow {
    id: toastPopup
    visible: toastRepeater.count > 0

    screen: Quickshell.screens[0]
    color: "transparent"
    exclusionMode: PanelWindow.ExclusionMode.Ignore
    focusable: false

    implicitWidth: 360
    implicitHeight: Math.min(toastColumn.implicitHeight + 16, 400)

    anchors {
        top: true
        right: true
    }

    margins {
        top: 40
        right: 8
    }

    function urgencyColor(urgency) {
        if (urgency === 2) return Theme.error;
        if (urgency === 1) return Theme.primary;
        return Theme.muted;
    }

    Column {
        id: toastColumn
        anchors.fill: parent
        anchors.margins: 4
        spacing: 6

        Repeater {
            id: toastRepeater
            model: NotificationState.toastModel

            delegate: Item {
                id: toastDelegate
                width: toastColumn.width - 8
                height: toastCard.height
                anchors.horizontalCenter: parent.horizontalCenter

                property real opacityValue: 1
                property real scaleValue: 1
                property bool closing: false

                Behavior on opacityValue {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }
                Behavior on scaleValue {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }

                function close() {
                    if (closing) return
                    closing = true
                    opacityValue = 0
                    scaleValue = 0.8
                    dismissTimer.stop()
                    closeTimer.start()
                }

                Timer {
                    id: closeTimer
                    interval: 200
                    onTriggered: {
                        if (NotificationState.service)
                            NotificationState.service.dismissToast(index)
                    }
                }

                Timer {
                    id: dismissTimer
                    interval: model.expireTimeout > 0
                        ? Math.min(model.expireTimeout, 8000)
                        : model.urgency === 2 ? 8000 : 4000
                    running: true
                    onTriggered: close()
                }

                Rectangle {
                    id: toastCard
                    width: parent.width
                    height: cardLayout.implicitHeight + 20
                    radius: 8
                    color: Theme.surface
                    border.color: borderColor
                    border.width: 1
                    clip: true
                    opacity: toastDelegate.opacityValue
                    scale: toastDelegate.scaleValue
                    transformOrigin: Item.Right

                    readonly property int urg: model.urgency
                    readonly property color borderColor: Qt.alpha(urgencyColor(urg), 0.4)

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 3
                        radius: 2
                        color: urgencyColor(urg)
                        anchors.topMargin: 6
                        anchors.bottomMargin: 6
                        anchors.leftMargin: 3
                    }

                    RowLayout {
                        id: cardLayout
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        Rectangle {
                            width: 28
                            height: 28
                            radius: 5
                            color: Qt.alpha(urgencyColor(urg), 0.12)
                            Layout.alignment: Qt.AlignTop

                            Text {
                                anchors.centerIn: parent
                                text: model.appName ? model.appName.charAt(0).toUpperCase() : "N"
                                color: urgencyColor(urg)
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }

                        ColumnLayout {
                            spacing: 2
                            Layout.fillWidth: true

                            Text {
                                text: model.appName || "Notification"
                                color: Theme.muted
                                font.pixelSize: 9
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
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
                                text: model.body
                                color: Qt.alpha(Theme.fg, 0.7)
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                visible: text.length > 0
                                Layout.fillWidth: true
                            }

                            // Optional: action buttons (will add later)
                        }

                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            color: closeMa.containsMouse ? Qt.alpha(Theme.muted, 0.2) : "transparent"
                            Layout.alignment: Qt.AlignTop

                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                color: Theme.muted
                                font.pixelSize: 10
                            }

                            MouseArea {
                                id: closeMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: close()
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        onClicked: close()
                    }
                }
            }
        }
    }
}