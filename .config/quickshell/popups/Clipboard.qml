import "../service"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

PopupPanel {
    id: root

    property var rawEntries: []
    property var filteredEntries: []
    property string searchQuery: ""
    property int selectedIndex: 0

    function refreshClipboard() {
        decodeScript.running = true;
    }

    function getEntryId(line) {
        if (!line)
            return "";

        var parts = line.split("\t");
        return parts[0] || "";
    }

    function getEntryText(line) {
        if (!line)
            return "";

        var parts = line.split("\t");
        return parts.length > 1 ? parts.slice(1).join("\t").trim() : line;
    }

    function isImageEntry(line) {
        return line && line.indexOf("binary data") !== -1;
    }

    function filterEntries() {
        var query = searchQuery.trim().toLowerCase();
        if (!query) {
            filteredEntries = rawEntries;
        } else {
            var temp = [];
            for (var i = 0; i < rawEntries.length; i++) {
                if (getEntryText(rawEntries[i]).toLowerCase().indexOf(query) !== -1)
                    temp.push(rawEntries[i]);

            }
            filteredEntries = temp;
        }
        selectedIndex = 0;
    }

    anchorSide: "left"
    panelWidth: 340
    panelMinHeight: 400
    contentMargin: 10
    onBeforeOpen: refreshClipboard()

    // ── Decode images to temp files ───────────────────────────
    Process {
        id: decodeScript

        command: [Theme.bin("decode_clipboard_images.sh")]
        running: false
        onExited: function(code) {
            if (code !== 0) {
                console.warn("Clipboard: image decode failed with code", code);
                return;
            }
            cliphistListProc.running = true;
        }
    }

    // ── List clipboard entries ────────────────────────────────
    Process {
        id: cliphistListProc

        command: ["cliphist", "list"]
        running: false
        onExited: function(code) {
            if (code !== 0)
                console.warn("Clipboard: cliphist list failed with code", code);
        }

        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                var temp = [];
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (line !== "")
                        temp.push(line);

                }
                rawEntries = temp;
                filterEntries();
            }
        }

    }

    // ── Copy entry ────────────────────────────────────────────
    Process {
        id: copyProc

        property string entryLine: ""

        command: ["sh", "-c", "d=$(printf '%s' \"$1\" | cliphist decode); printf '%s' \"$d\" | wl-copy && notify-send -t 1000 -h string:x-canonical-private-synchronous:clip-notify -a clipboard -i edit-copy \"copied\" \"$(printf '%s' \"$d\" | head -c 50)\"", "_", entryLine]
        running: false
        onExited: function(code) {
            if (code !== 0) {
                console.warn("Clipboard: copy failed with code", code);
                return;
            }
            root.showPopup = false;
        }
    }

    // ── Delete entry ──────────────────────────────────────────
    Process {
        id: deleteProc

        property string entryLine: ""

        command: ["sh", "-c", "printf '%s' \"$1\" | cliphist delete && id=$(printf '%s' \"$1\" | cut -f1) && rm -f \"" + Theme.tmpDir + "/clip_${id}.png\"", "_", entryLine]
        running: false
        onExited: function(code) {
            if (code !== 0) {
                console.warn("Clipboard: delete failed with code", code);
                return;
            }
            refreshClipboard();
        }
    }

    // ── Wipe all ──────────────────────────────────────────────
    Process {
        id: wipeProc

        command: ["sh", "-c", "cliphist wipe && rm -f \"" + Theme.tmpDir + "/clip_*.png\""]
        running: false
        onExited: function(code) {
            if (code !== 0) {
                console.warn("Clipboard: wipe failed with code", code);
                return;
            }
            refreshClipboard();
        }
    }

    // ── Content ───────────────────────────────────────────────
    contentComponent: Component {
        FocusScope {
            anchors.fill: parent
            implicitWidth: contentLayout.implicitWidth
            implicitHeight: contentLayout.implicitHeight
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                    if (root.selectedIndex > 0) {
                        root.selectedIndex--;
                        entryList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                    }
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                    if (root.selectedIndex < root.filteredEntries.length - 1) {
                        root.selectedIndex++;
                        entryList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                    }
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (root.filteredEntries.length > 0 && root.selectedIndex < root.filteredEntries.length) {
                        copyProc.entryLine = root.filteredEntries[root.selectedIndex];
                        copyProc.running = true;
                    }
                    event.accepted = true;
                } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
                    if (root.filteredEntries.length > 0 && root.selectedIndex < root.filteredEntries.length) {
                        deleteProc.entryLine = root.filteredEntries[root.selectedIndex];
                        deleteProc.running = true;
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

                // ── Header ────────────────────────────
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 22

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰅈  Clipboard"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize2xl
                        font.bold: true
                    }

                    Text {
                        id: clearText

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "clear all"
                        color: clearBtn.containsMouse ? Theme.error : Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLg

                        MouseArea {
                            id: clearBtn

                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: wipeProc.running = true
                        }

                    }

                }

                // ── Search bar ────────────────────────
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
                        clip: true // Prevent character bleeding on long queries
                        onTextChanged: {
                            root.searchQuery = text;
                            root.filterEntries();
                        }
                        Keys.onPressed: (event) => {
                            var navKeys = [Qt.Key_Up, Qt.Key_Down, Qt.Key_Return, Qt.Key_Enter, Qt.Key_Delete, Qt.Key_K, Qt.Key_J];
                            if (navKeys.indexOf(event.key) !== -1) {
                                event.accepted = false;
                                return ;
                            }
                            if (event.key === Qt.Key_Backspace && searchInput.text === "") {
                                event.accepted = false;
                                return ;
                            }
                        }

                        Text {
                            text: "Search clipboard..."
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXl
                            visible: searchInput.text === ""
                            anchors.verticalCenter: parent.verticalCenter
                        }

                    }

                }

                // ── Entry list ─────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "transparent"

                    ListView {
                        id: entryList

                        anchors.fill: parent
                        clip: true
                        model: root.filteredEntries
                        spacing: 3 // Elevated spacing for visual parity

                        Text {
                            anchors.centerIn: parent
                            text: root.searchQuery ? "No matches" : "Clipboard is empty"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLg
                            visible: root.filteredEntries.length === 0
                        }

                        delegate: Rectangle {
                            width: entryList.width
                            height: root.isImageEntry(modelData) ? 44 : 26
                            color: root.selectedIndex === index ? Qt.alpha(Theme.primary, 0.12) : "transparent"
                            radius: 4

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: root.selectedIndex = index
                                onClicked: {
                                    copyProc.entryLine = modelData;
                                    copyProc.running = true;
                                }
                                onPressed: (mouse) => {
                                    if (mouse.button === Qt.RightButton) {
                                        deleteProc.entryLine = modelData;
                                        deleteProc.running = true;
                                    }
                                }
                            }

                            // Strictly anchored components replacing loose Row structures
                            Text {
                                id: typeIcon

                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: 16
                                text: root.isImageEntry(modelData) ? "󰉦" : "󰅈"
                                color: root.selectedIndex === index ? Theme.primary : Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLg
                            }

                            Item {
                                anchors.left: typeIcon.right
                                anchors.leftMargin: 8
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                height: parent.height

                                Image {
                                    visible: root.isImageEntry(modelData)
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectFit
                                    source: root.isImageEntry(modelData) ? "file://" + Theme.tmpDir + "/clip_" + root.getEntryId(modelData) + ".png" : ""
                                    cache: false
                                }

                                Text {
                                    visible: !root.isImageEntry(modelData)
                                    anchors.fill: parent
                                    text: root.getEntryText(modelData)
                                    color: Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeLg
                                    elide: Text.ElideRight
                                    wrapMode: Text.NoWrap
                                    verticalAlignment: Text.AlignVCenter
                                }

                            }

                        }

                    }

                }

            }

        }

    }

}
