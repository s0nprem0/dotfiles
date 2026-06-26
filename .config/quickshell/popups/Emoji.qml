import "../service"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

PopupPanel {
    id: root

    property var allEmojis: []
    property var filteredEmojis: []
    property string searchQuery: ""
    property int selectedIndex: 0

    function filterEmojis() {
        var query = searchQuery.trim().toLowerCase();
        if (!query) {
            filteredEmojis = allEmojis;
        } else {
            var temp = [];
            for (var i = 0; i < allEmojis.length; i++) {
                if (allEmojis[i].name.indexOf(query) !== -1)
                    temp.push(allEmojis[i]);

            }
            filteredEmojis = temp;
        }
        if (selectedIndex >= filteredEmojis.length)
            selectedIndex = Math.max(0, filteredEmojis.length - 1);

    }

    anchorSide: "left"
    panelWidth: 340
    panelMinHeight: 400
    panelMaxHeight: 500
    contentMargin: 10

    FileView {
        path: "file://" + Theme.home + "/.config/quickshell/emojis.json"
        onLoaded: {
            try {
                root.allEmojis = JSON.parse(text);
                root.filterEmojis();
            } catch (e) {
                console.log("Emoji: failed to parse emojis.json:", e);
            }
        }
    }

    Process {
        id: copyProc

        property string emojiChar: ""

        command: ["sh", "-c", "echo -n \"$1\" | wl-copy && notify-send -t 1000 -h string:x-canonical-private-synchronous:emoji-notify -a \"emoji picker\" -i \"edit-copy\" \"copied to clipboard\" \"$1\"", "sh", emojiChar]
        running: false
        onExited: {
            root.showPopup = false;
        }
    }

    // ── Content ───────────────────────────────────────────────
    contentComponent: Component {
        FocusScope {
            anchors.fill: parent
            implicitWidth: contentLayout.implicitWidth
            implicitHeight: contentLayout.implicitHeight
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Up) {
                    if (root.selectedIndex >= 5)
                        root.selectedIndex -= 5;

                    event.accepted = true;
                } else if (event.key === Qt.Key_Down) {
                    if (root.selectedIndex + 5 < root.filteredEmojis.length)
                        root.selectedIndex += 5;

                    event.accepted = true;
                } else if (event.key === Qt.Key_Left) {
                    if (root.selectedIndex > 0)
                        root.selectedIndex--;

                    event.accepted = true;
                } else if (event.key === Qt.Key_Right) {
                    if (root.selectedIndex < root.filteredEmojis.length - 1)
                        root.selectedIndex++;

                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (root.filteredEmojis.length > 0 && root.selectedIndex < root.filteredEmojis.length) {
                        copyProc.emojiChar = root.filteredEmojis[root.selectedIndex].char;
                        copyProc.running = true;
                    }
                    event.accepted = true;
                }
            }

            Connections {
                function onAfterOpen() {
                    searchInput.forceActiveFocus();
                }

                target: root
            }

            ColumnLayout {
                id: contentLayout

                anchors.fill: parent
                spacing: 6

                // ── Header ──
                Text {
                    text: "󰞍  Emoji Picker"
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize2xl
                    font.bold: true
                }

                // ── Search bar ──
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    color: Theme.surface
                    radius: 4
                    border.color: searchInput.activeFocus ? Theme.primary : "transparent"
                    border.width: 1

                    TextInput {
                        id: searchInput

                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXl
                        onTextChanged: {
                            root.searchQuery = text;
                            root.filterEmojis();
                        }

                        Text {
                            text: "Search emoji..."
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXl
                            visible: searchInput.text === ""
                            anchors.verticalCenter: parent.verticalCenter
                        }

                    }

                }

                // ── Emoji grid ──
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "transparent"

                    GridView {
                        id: gridView

                        anchors.fill: parent
                        clip: true
                        cellWidth: Math.floor(gridView.width / 5)
                        cellHeight: 38
                        model: root.filteredEmojis

                        Text {
                            anchors.centerIn: parent
                            text: root.allEmojis.length === 0 ? "Loading..." : "No matches"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLg
                            visible: root.filteredEmojis.length === 0
                        }

                        delegate: Rectangle {
                            width: gridView.cellWidth - 2
                            height: gridView.cellHeight - 2
                            color: root.selectedIndex === index ? Qt.alpha(Theme.primary, 0.15) : "transparent"
                            radius: 4

                            Text {
                                anchors.centerIn: parent
                                text: modelData.char
                                font.pixelSize: Theme.fontSize5xl
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: root.selectedIndex = index
                                onClicked: {
                                    copyProc.emojiChar = modelData.char;
                                    copyProc.running = true;
                                }
                            }

                        }

                    }

                }

            }

        }

    }

}
