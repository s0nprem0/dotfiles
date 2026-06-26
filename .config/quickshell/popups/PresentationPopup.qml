import "../components"
import "../service"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

Window {
    id: root

    property bool showPopup: false
    property string currentMode: DisplayService.currentMode
    property var modes: [
        { name: "EXTEND", value: "extend", desc: "Two separate screens" },
        { name: "DUPLICATE", value: "duplicate", desc: "Mirror displays" },
        { name: "EXTERNAL", value: "external", desc: "External only" },
        { name: "INTERNAL", value: "internal", desc: "Laptop screen only" }
    ]

    function applyMode(mode) {
        var result = Quickshell.execDetached([Theme.bin("display_toggle"), mode]);
        root.showPopup = false;
        DisplayService.refreshMonitors();
    }

    title: "DISPLAY MODE"
    minimumWidth: 260
    minimumHeight: 240
    width: 260
    height: 240
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint
    visible: showPopup

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            root.showPopup = false;
            event.accepted = true;
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
            var idx = modes.findIndex(function(m) { return m.value === root.currentMode; });
            var nextIdx = (idx + 1) % modes.length;
            root.applyMode(modes[nextIdx].value);
            event.accepted = true;
        }
    }

    Component.onCompleted: {
        forceActiveFocus();
    }

    onShowPopupChanged: {
        if (showPopup) {
            forceActiveFocus();
            DisplayService.refreshMonitors();
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 8
        color: Theme.surface
        border.width: 6
        border.color: Theme.primary

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                color: Theme.primary

                Text {
                    anchors.centerIn: parent
                    text: "DISPLAY MODE"
                    color: Theme.bg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize3xl
                    font.bold: true
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 2
                color: Theme.bg
            }

            Repeater {
                model: modes

                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    color: modelData.value === root.currentMode ? Theme.primary : Theme.surface
                    border.width: 3
                    border.color: Theme.primary

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        Text {
                            text: modelData.name
                            color: modelData.value === root.currentMode ? Theme.bg : Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXl
                            font.bold: true
                            Layout.fillWidth: true
                        }

                        MouseArea {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.applyMode(modelData.value);
                            }

                            Text {
                                anchors.centerIn: parent
                                text: ">"
                                color: modelData.value === root.currentMode ? Theme.bg : Theme.primary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize3xl
                                font.bold: true
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.applyMode(modelData.value);
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 2
                color: Theme.bg
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                spacing: 4

                Text {
                    text: "[SPACE/ENTER] CYCLE"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                    font.bold: true
                }

                Text {
                    text: "ESC CLOSE"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                    font.bold: true
                    Layout.alignment: Qt.AlignRight
                }
            }
        }
    }
}
