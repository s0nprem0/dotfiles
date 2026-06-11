import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../service"

PopupPanel {
    id: root

    anchorSide: "left"
    panelWidth: 340
    panelMinHeight: 400
    contentMargin: 10

    property var rawEntries: []
    property var filteredEntries: []
    property string searchQuery: ""
    property int selectedIndex: 0

    onBeforeOpen: refreshClipboard()

    function refreshClipboard() {
        decodeScript.running = true
    }

    function getEntryId(line) {
        if (!line) return ""
        var parts = line.split("\t")
        return parts[0] || ""
    }

    function getEntryText(line) {
        if (!line) return ""
        var parts = line.split("\t")
        return parts.length > 1 ? parts.slice(1).join("\t").trim() : line
    }

    function isImageEntry(line) {
        return line && line.indexOf("binary data") !== -1
    }

    function filterEntries() {
        var query = searchQuery.trim().toLowerCase()
        if (!query) {
            filteredEntries = rawEntries
        } else {
            var temp = []
            for (var i = 0; i < rawEntries.length; i++) {
                if (getEntryText(rawEntries[i]).toLowerCase().indexOf(query) !== -1)
                    temp.push(rawEntries[i])
            }
            filteredEntries = temp
        }
        selectedIndex = 0
    }

    // ── Decode images to temp files ───────────────────────────
    Process {
        id: decodeScript
        command: [Theme.bin("decode_clipboard_images.sh")]
        running: false
        onExited: { cliphistListProc.running = true }
    }

    // ── List clipboard entries ────────────────────────────────
    Process {
        id: cliphistListProc
        command: ["cliphist", "list"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n")
                var temp = []
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()
                    if (line !== "") temp.push(line)
                }
                rawEntries = temp
                filterEntries()
            }
        }
    }

    // ── Copy entry ────────────────────────────────────────────
    Process {
        id: copyProc
        property string entryLine: ""
        command: ["sh", "-c", "d=$(echo \"$1\" | cliphist decode); echo -n \"$d\" | wl-copy && notify-send -t 1000 -h string:x-canonical-private-synchronous:clip-notify -a clipboard -i edit-copy \"copied\" \"$(echo -n \"$d\" | head -c 50)\"", "_", entryLine]
        running: false
        onExited: { root.showPopup = false }
    }

    // ── Delete entry ──────────────────────────────────────────
    Process {
        id: deleteProc
        property string entryLine: ""
        command: ["sh", "-c", "echo \"$1\" | cliphist delete", "_", entryLine]
        running: false
        onExited: { refreshClipboard() }
    }

    // ── Wipe all ──────────────────────────────────────────────
    Process {
        id: wipeProc
        command: ["cliphist", "wipe"]
        running: false
        onExited: { refreshClipboard() }
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
                        root.selectedIndex--
                        entryList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                    if (root.selectedIndex < root.filteredEntries.length - 1) {
                        root.selectedIndex++
                        entryList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (root.filteredEntries.length > 0 && root.selectedIndex < root.filteredEntries.length) {
                        copyProc.entryLine = root.filteredEntries[root.selectedIndex]
                        copyProc.running = true
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
                    if (root.filteredEntries.length > 0 && root.selectedIndex < root.filteredEntries.length) {
                        deleteProc.entryLine = root.filteredEntries[root.selectedIndex]
                        deleteProc.running = true
                    }
                    event.accepted = true
                }
            }

            Connections {
                target: root
                function onAfterOpen() { searchInput.forceActiveFocus() }
            }

            ColumnLayout {
                id: contentLayout
                anchors.fill: parent
                spacing: 6

            // ── Header ────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: "󰅈  Clipboard"
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "clear all"
                    color: clearBtn.containsMouse ? Theme.error : Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 11

                    MouseArea {
                        id: clearBtn
                        anchors.fill: parent
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
                    font.pixelSize: 12

                    onTextChanged: {
                        root.searchQuery = text
                        root.filterEntries()
                    }

                    Text {
                        text: "Search clipboard..."
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
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
                    spacing: 2

                    delegate: Rectangle {
                        width: entryList.width
                        height: root.isImageEntry(modelData) ? 40 : 24
                        color: root.selectedIndex === index ? Qt.alpha(Theme.primary, 0.15) : "transparent"
                        radius: 3

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.selectedIndex = index
                            onClicked: {
                                copyProc.entryLine = modelData
                                copyProc.running = true
                            }
                            onPressed: {
                                if (mouse.button === Qt.RightButton) {
                                    deleteProc.entryLine = modelData
                                    deleteProc.running = true
                                }
                            }
                        }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            spacing: 6

                            Text {
                                text: root.isImageEntry(modelData) ? "🖼" : "󰅈"
                                color: root.selectedIndex === index ? Theme.primary : Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                anchors.verticalCenter: parent.verticalCenter
                                width: 16
                            }

                            Rectangle {
                                width: parent.width - 22
                                height: parent.height
                                color: "transparent"

                                Image {
                                    visible: root.isImageEntry(modelData)
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectFit
                                    source: root.isImageEntry(modelData) ? "file:///tmp/clip_" + root.getEntryId(modelData) + ".png" : ""
                                    cache: false
                                }

                                Text {
                                    visible: !root.isImageEntry(modelData)
                                    anchors.fill: parent
                                    text: root.getEntryText(modelData)
                                    color: root.selectedIndex === index ? Theme.fg : Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    wrapMode: Text.NoWrap
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                    }

                    // ── Empty state ─────────────────
                    Text {
                        anchors.centerIn: parent
                        text: root.searchQuery ? "No matches" : "Clipboard is empty"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        visible: root.filteredEntries.length === 0
                    }
                }
            }
        }
        }
    }
}
