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
    property string pendingAction: ""
    property string pendingLabel: ""

    signal confirmAction(string action, string label)
    signal closeConfirm()
    signal executeAction(var cmd)

    color: "transparent"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        // Header Card
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 90
            color: Theme.surface
            border.width: 1
            border.color: Theme.primary
            radius: 0

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 4
                Text { text: "Hello, " + root.hostname.split(".")[0]; font.pixelSize: 18; color: Theme.fg; font.bold: true }
                Text { text: root.os; font.pixelSize: 11; color: Theme.muted }
            }
        }

        // Quick Actions
        GridLayout {
            Layout.fillWidth: true
            columns: 5
            columnSpacing: 8
            rowSpacing: 8

            Repeater {
                model: root.sysActions
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    color: Theme.surface
                    border.width: 1
                    border.color: Theme.primary

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: modelData.icon; font.pixelSize: 20; color: Theme.primary }
                        Text { text: modelData.label; font.pixelSize: 9; color: Theme.fg; font.bold: true }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (modelData.confirm) {
                                root.confirmAction(modelData.cmd, modelData.label);
                            } else {
                                root.executeAction(modelData.cmd);
                            }
                        }
                    }
                }
            }
        }

        // Confirmation Dialog (overlay)
        Rectangle {
            visible: root.confirmVisible
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.7)
            z: 10

            Rectangle {
                anchors.centerIn: parent
                width: 280
                height: 140
                color: Theme.bg
                border.width: 2
                border.color: Theme.error

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    Text {
                        text: "Confirm " + root.pendingLabel + "?"
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        color: Theme.fg
                        font.pixelSize: 13
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
                            Text { anchors.centerIn: parent; text: "Cancel"; color: Theme.fg }
                            MouseArea { anchors.fill: parent; onClicked: root.closeConfirm() }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            color: Theme.error
                            Text { anchors.centerIn: parent; text: "Confirm"; color: Theme.bg; font.bold: true }
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
