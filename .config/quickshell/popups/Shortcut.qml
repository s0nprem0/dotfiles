import "../components"
import "../service"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

PopupPanel {
    id: root

    property var rawData: []
    property var displayData: []
    property string searchText: ""
    property int filteredCount: 0

    function rebuildDisplay() {
        var term = root.searchText.toLowerCase().trim();
        var filtered = [];
        var rawLen = root.rawData.length;
        for (var i = 0; i < rawLen; i++) {
            var item = root.rawData[i];
            if (term === "" || item.keys.toLowerCase().indexOf(term) >= 0 || item.description.toLowerCase().indexOf(term) >= 0 || item.category.toLowerCase().indexOf(term) >= 0)
                filtered.push(item);

        }
        var result = [];
        var lastCat = "";
        for (var j = 0; j < filtered.length; j++) {
            var it = filtered[j];
            if (it.category !== lastCat) {
                result.push({
                    "isHeader": true,
                    "category": it.category
                });
                lastCat = it.category;
            }
            result.push(it);
        }
        root.filteredCount = filtered.length;
        root.displayData = result;
    }

    anchorSide: "none"
    panelWidth: 400
    panelMinHeight: 140
    panelMaxHeight: 620
    contentMargin: 14
    onBeforeOpen: {
        parseProc.running = true;
    }

    Process {
        id: parseProc

        running: false
        command: [Theme.bin("parse_binds"), Theme.config("hypr/binds.lua")]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.rawData = JSON.parse(this.text || "[]");
                    root.rebuildDisplay();
                } catch (e) {
                    root.rawData = [];
                    root.displayData = [];
                }
            }
        }

    }

    Process {
        id: copyCmd

        running: false
    }

    contentComponent: Component {
        Item {
            id: contentRoot

            implicitWidth: 400 - root.contentMargin * 2
            implicitHeight: headerBar.height + listView.contentHeight + 40

            // Header
            Rectangle {
                id: headerBar

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 42
                color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    spacing: 10

                    Text {
                        text: "Keybindings"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize2xl
                        font.bold: true
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        radius: 6
                        color: Theme.surface
                        border.width: 1
                        border.color: searchField.activeFocus ? Theme.primary : Theme.surfaceLighter

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 6
                            spacing: 6

                            TextInput {
                                id: searchField

                                Layout.fillWidth: true
                                verticalAlignment: TextInput.AlignVCenter
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLg
                                selectByMouse: true
                                onTextChanged: {
                                    root.searchText = text;
                                    root.rebuildDisplay();
                                }
                            }

                            Text {
                                text: "⌫"
                                color: Theme.muted
                                font.pixelSize: Theme.fontSize3xl
                                visible: searchField.text !== ""

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        searchField.text = "";
                                        searchField.forceActiveFocus();
                                    }
                                }

                            }

                        }

                    }

                    Text {
                        text: root.searchText ? (root.filteredCount + "/" + root.rawData.length) : root.filteredCount + ""
                        color: Theme.muted
                        font.pixelSize: Theme.fontSizeMd
                        font.family: Theme.fontFamily
                    }

                }

            }

            // Empty state
            Text {
                id: emptyText

                anchors.top: headerBar.bottom
                anchors.topMargin: 40
                anchors.horizontalCenter: parent.horizontalCenter
                visible: searchField.text !== "" && root.displayData.length === 0
                text: "No matching shortcuts found"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLg
            }

            // Copy toast
            Rectangle {
                id: copyToast

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 16
                width: copyLabel.width + 24
                height: 28
                radius: 6
                color: Theme.primary
                opacity: 0
                visible: opacity > 0

                Text {
                    id: copyLabel

                    anchors.centerIn: parent
                    text: ""
                    color: Theme.bg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMd
                    font.bold: true
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                    }

                }

            }

            Timer {
                id: copyTimer

                interval: 800
                onTriggered: copyToast.opacity = 0
            }

            // Main list
            ListView {
                id: listView

                anchors.top: headerBar.bottom
                anchors.topMargin: 8
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                model: root.displayData
                spacing: 2
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                implicitHeight: contentHeight

                delegate: Item {
                    required property var modelData

                    width: ListView.view.width
                    height: modelData.isHeader ? 32 : 34

                    // Header
                    Rectangle {
                        anchors.fill: parent
                        visible: modelData.isHeader
                        color: "transparent"

                        Separator {
                            anchors.top: parent.top
                            anchors.topMargin: 4
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.top: parent.top
                            anchors.topMargin: 9
                            text: modelData.category || ""
                            color: Theme.primary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeMd
                            font.bold: true
                            opacity: 0.85
                        }

                    }

                    // Binding item
                    Rectangle {
                        visible: !modelData.isHeader
                        anchors.fill: parent
                        radius: 6
                        color: ma.containsMouse ? Theme.surfaceLighter : "transparent"

                        MouseArea {
                            id: ma

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.keys) {
                                    copyCmd.command = ["sh", "-c", "echo -n \"$1\" | wl-copy", "_", modelData.keys];
                                    copyCmd.running = true;
                                    copyLabel.text = "Copied!";
                                    copyToast.opacity = 1;
                                    copyTimer.restart();
                                }
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 12
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: keyLabel.implicitWidth + 16
                                Layout.preferredHeight: 22
                                radius: 5
                                color: Theme.primary
                                clip: true

                                Text {
                                    id: keyLabel

                                    anchors.centerIn: parent
                                    width: Math.min(implicitWidth, parent.width - 8)
                                    text: modelData.keys || ""
                                    color: Theme.bg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSm
                                    font.bold: true
                                }

                            }

                            Text {
                                text: modelData.description || ""
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLg
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                        }

                    }

                }

            }

        }

    }

}
