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
    property int monitorCount: DisplayService.monitorCount
    property var modes: [{
        "name": "EXTEND",
        "value": "extend",
        "desc": "Two separate screens",
        "icon": "🖥️"
    }, {
        "name": "DUPLICATE",
        "value": "duplicate",
        "desc": "Mirror displays",
        "icon": "🔄"
    }, {
        "name": "EXTERNAL",
        "value": "external",
        "desc": "External only",
        "icon": "📺"
    }, {
        "name": "INTERNAL",
        "value": "internal",
        "desc": "Laptop screen only",
        "icon": "💻"
    }]

    function applyMode(mode) {
        var result = Quickshell.execDetached([Theme.bin("display_toggle"), mode]);
        root.showPopup = false;
        DisplayService.refreshMonitors();
    }

    function cycleMode() {
        var idx = modes.findIndex(function(m) {
            return m.value === root.currentMode;
        });
        var nextIdx = (idx + 1) % modes.length;
        root.applyMode(modes[nextIdx].value);
    }

    title: "DISPLAY MODE"
    minimumWidth: 320
    minimumHeight: 280
    width: 320
    height: 280
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint
    visible: showPopup
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            root.showPopup = false;
            event.accepted = true;
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
            root.cycleMode();
            event.accepted = true;
        }
    }
    onShowPopupChanged: {
        if (showPopup)
            DisplayService.refreshMonitors();

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
                Layout.preferredHeight: 48
                color: Theme.primary
                anchors.topMargin: 8

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    Text {
                        text: "🖥️"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize2xl
                    }

                    Text {
                        text: "DISPLAY MODE"
                        color: Theme.bg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize3xl
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        implicitWidth: monitorCount > 0 ? 24 : 0
                        implicitHeight: 24
                        radius: 12
                        color: Theme.bg
                        border.width: 1
                        border.color: Theme.primary

                        Text {
                            anchors.centerIn: parent
                            text: root.monitorCount
                            color: Theme.primary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            font.bold: true
                            visible: root.monitorCount > 0
                        }

                    }

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
                    Layout.preferredHeight: 56
                    color: modelData.value === root.currentMode ? Theme.primaryAlpha015 : Theme.surface
                    border.width: 1
                    border.color: modelData.value === root.currentMode ? Theme.primary : Theme.surfaceLighter

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        Text {
                            text: modelData.icon
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize2xl
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: modelData.name
                                color: modelData.value === root.currentMode ? Theme.bg : Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeXl
                                font.bold: true
                                Layout.fillWidth: true
                            }

                            Text {
                                text: modelData.desc
                                color: modelData.value === root.currentMode ? Theme.muted : Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                                elide: Text.ElideRight
                            }

                        }

                        Text {
                            text: modelData.value === root.currentMode ? "✓" : ">"
                            color: modelData.value === root.currentMode ? Theme.primary : Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize2xl
                            font.bold: true
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
                Layout.preferredHeight: 32
                spacing: 4
                anchors.bottomMargin: 8

                Text {
                    text: "SPACE/ENTER: CYCLE  ESC: CLOSE"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                    font.bold: true
                    Layout.fillWidth: true
                }

            }

        }

    }

}
