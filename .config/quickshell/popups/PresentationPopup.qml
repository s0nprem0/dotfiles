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
    property int selectedModeIndex: 0

    property var modes: [{
        "name": "EXTEND",
        "value": "extend",
        "desc": "Two separate screens"
    }, {
        "name": "DUPLICATE",
        "value": "duplicate",
        "desc": "Mirror displays"
    }]

    function applyMode(mode) {
        Quickshell.execDetached([Theme.bin("display_toggle"), mode]);
        root.showPopup = false;
        DisplayService.refreshMonitors();
    }

    function cycleMode() {
        root.selectedModeIndex = (root.selectedModeIndex + 1) % root.modes.length;
        root.applyMode(root.modes[root.selectedModeIndex].value);
    }

    title: "DISPLAY MODE"
    minimumWidth: 320
    minimumHeight: 200
    width: 320
    height: 200
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
        if (showPopup) {
            DisplayService.refreshMonitors();
            var idx = root.modes.findIndex(function(m) { return m.value === root.currentMode; });
            root.selectedModeIndex = idx >= 0 ? idx : 0;
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 8
        color: Theme.surface

        Column {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                width: parent.width
                height: 36
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

            Repeater {
                model: root.modes

                delegate: Rectangle {
                    required property var modelData

                    width: parent.width
                    height: 36
                    color: modelData.value === root.currentMode ? Theme.primary : Theme.surface

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12

                        Text {
                            text: modelData.name
                            color: modelData.value === root.currentMode ? Theme.bg : Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXl
                            font.bold: true
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Text {
                            text: modelData.desc
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                        }

                        Text {
                            text: modelData.value === root.currentMode ? "[active]" : ">"
                            color: modelData.value === root.currentMode ? Theme.primary : Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            font.bold: true
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.applyMode(modelData.value)
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 24
                color: Theme.surfaceLighter

                Text {
                    anchors.centerIn: parent
                    text: "SPACE/ENTER: CYCLE  ESC: CLOSE"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                    font.bold: true
                }
            }
        }
    }

}