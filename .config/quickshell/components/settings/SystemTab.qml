import "../../service"
import QtQuick
import QtQuick.Layouts
import Quickshell

Rectangle {
    id: root

    property string hostname: ""
    property string os: ""
    property string uptime: ""
    property string batteryPercent: "--"
    property bool charging: false
    property var sysActions: []
    property bool confirmVisible: false
    property var pendingAction: ""
    property string pendingLabel: ""

    signal confirmAction(var action, string label)
    signal closeConfirm()
    signal executeAction(var cmd)

    color: "transparent"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        HeaderCard {
            hostname: root.hostname
            os: root.os
            uptime: root.uptime
            batteryPercent: root.batteryPercent
            charging: root.charging
        }

        // ── Quick actions ──
        Text {
            text: "ACTIONS"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLg
            color: Theme.primary
            font.bold: true
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: 10
            rowSpacing: 10

            Repeater {
                model: root.sysActions

                delegate: Rectangle {
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    color: ma.containsMouse ? Theme.primary : Theme.bg
                    border.width: 1
                    border.color: Theme.primary

                    ColumnLayout {
                        anchors.centerIn: parent
                        anchors.margins: 10
                        spacing: 4

                        Text {
                            text: modelData.icon
                            color: ma.containsMouse ? Theme.bg : Theme.primary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize6xl
                        }

                        Text {
                            text: modelData.label
                            color: ma.containsMouse ? Theme.bg : Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            font.bold: true
                            elide: Text.ElideRight
                        }

                    }

                    MouseArea {
                        id: ma

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.confirm)
                                root.confirmAction(modelData.cmd, modelData.label);
                            else
                                root.executeAction(modelData.cmd);
                        }
                    }

                }

            }

        }

        // ── Confirm dialog overlay ──
        Rectangle {
            visible: root.confirmVisible
            anchors.fill: parent
            z: 10
            color: Qt.rgba(0, 0, 0, 0.7)

            Rectangle {
                anchors.centerIn: parent
                width: 300
                height: 130
                color: Theme.bg
                border.width: 2
                border.color: Theme.error

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    Text {
                        text: "CONFIRM " + root.pendingLabel.toUpperCase() + "?"
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        color: Theme.error
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXl
                        font.bold: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            color: Theme.surface
                            border.width: 1
                            border.color: Theme.primary

                            Text {
                                anchors.centerIn: parent
                                text: "CANCEL"
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeMd
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.closeConfirm()
                            }

                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            color: Theme.error

                            Text {
                                anchors.centerIn: parent
                                text: "CONFIRM"
                                color: Theme.bg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeMd
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    root.executeAction(root.pendingAction);
                                    root.closeConfirm();
                                }
                            }

                        }

                    }

                }

            }

        }

    }

}
