import "../service"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

PopupPanel {
    id: root

    property var presets: []
    property string filterText: ""

    panelWidth: 380
    panelMaxHeight: 520
    popupName: "theme-picker"
    anchorSide: "right"

    function refresh() {
        listPresetsProc.running = true;
    }

    onShowPopupChanged: {
        if (showPopup) refresh();
    }

    function applyPreset(file) {
        applyProc.command = [Theme.bin("apply_preset"), file];
        applyProc.running = true;
    }

    Process {
        id: listPresetsProc
        command: [Theme.bin("list_presets")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(this.text.trim());
                    root.presets = d.presets || [];
                } catch (e) { console.warn("ThemePicker: parse error", e); }
            }
        }
    }

    Process {
        id: applyProc
        onExited: {
            if (exitCode === 0) {
                Quickshell.execDetached(["pkill", "-SIGUSR1", "quickshell"]);
            }
        }
    }

    contentComponent: ColumnLayout {
        spacing: 10

        Text {
            text: "THEME PRESETS"
            color: Theme.primary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeXl
            font.bold: true
        }

        TextField {
            id: searchField
            Layout.fillWidth: true
            implicitHeight: 30
            placeholderText: "Filter themes..."
            color: Theme.fg
            placeholderTextColor: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLg
            onTextChanged: root.filterText = text.toLowerCase()
            background: Rectangle {
                color: Theme.surface
                border.width: 1
                border.color: Theme.primary
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.alpha(Theme.primary, 0.3)
        }

        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 400)
            contentHeight: listColumn.implicitHeight
            clip: true
            interactive: contentHeight > height

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            ColumnLayout {
                id: listColumn
                width: parent.width
                spacing: 6

                Repeater {
                    model: {
                        var f = root.filterText;
                        if (!f) return root.presets;
                        return root.presets.filter(function(p) {
                            return p.name.toLowerCase().indexOf(f) >= 0;
                        });
                    }

                    delegate: Rectangle {
                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: 44
                        color: applyMa.containsMouse ? Theme.surfaceLighter : "transparent"
                        border.width: 1
                        border.color: applyMa.containsMouse ? Theme.primary : Qt.alpha(Theme.primary, 0.2)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            Rectangle {
                                implicitWidth: 16
                                implicitHeight: 16
                                color: modelData.primary || Theme.primary
                                radius: 2
                            }

                            ColumnLayout {
                                spacing: 2
                                Layout.fillWidth: true

                                Text {
                                    text: modelData.name || "Unknown"
                                    color: Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeLg
                                    font.bold: true
                                }

                                Text {
                                    text: (modelData.variant || "dark").toUpperCase()
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSm
                                }
                            }

                            Text {
                                text: "󰄬"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize3xl
                            }
                        }

                        MouseArea {
                            id: applyMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.applyPreset(modelData.file);
                                root.showPopup = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
