import "../service"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io

Window {
    id: root

    property bool showPopup: false
    property var displayData: []
    property string searchText: ""
    property int selectedIndex: 0
    property int _fileSeq: 0

    function fuzzyMatch(str, query) {
        if (query === "")
            return true;

        str = (str || "").toLowerCase();
        query = query.toLowerCase();
        var j = 0;
        for (var i = 0; i < str.length && j < query.length; i++) {
            if (str[i] === query[j])
                j++;
        }
        return j === query.length;
    }

    function moveUp() {
        if (root.selectedIndex > 0) {
            root.selectedIndex--;
            listView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        }
    }

    function moveDown() {
        if (root.selectedIndex < root.displayData.length - 1) {
            root.selectedIndex++;
            listView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        }
    }

    function rebuildDisplay() {
        var term = root.searchText.trim();
        var sourceApps = AppsService.rawData.all_apps || [];
        var mostUsed = AppsService.rawData.most_used || [];
        var webHistory = AppsService.rawData.web_history || [];
        var filtered = [];

        if (term === "") {
            if (mostUsed.length > 0) {
                filtered.push({ typeLabel: "HEADER", name: "MOST USED" });
                for (let i = 0; i < mostUsed.length; i++) {
                    let item = Object.assign({}, mostUsed[i]);
                    item.typeLabel = "APP";
                    filtered.push(item);
                }
            }
            filtered.push({ typeLabel: "HEADER", name: "ALL APPS" });
            for (let i = 0; i < sourceApps.length; i++) {
                let item = Object.assign({}, sourceApps[i]);
                item.typeLabel = "APP";
                filtered.push(item);
            }
        } else if (term.startsWith("!")) {
            var searchQuery = term.substring(1).trim();
            if (webHistory.length > 0) {
                filtered.push({ typeLabel: "HEADER", name: "WEB HISTORY" });
                for (let i = 0; i < webHistory.length; i++) {
                    filtered.push({
                        typeLabel: "WEB",
                        name: webHistory[i].query,
                        icon: "󰖟",
                        comment: "via " + webHistory[i].engine,
                        url: webHistory[i].url
                    });
                }
            }
            filtered.push({
                typeLabel: "SEARCH",
                name: searchQuery ? "SEARCH \"" + searchQuery.toUpperCase() + "\"" : "EXECUTE WEB QUERY",
                icon: "󰖟",
                comment: term,
                query: term,
                isWebAction: true
            });
        } else if (term.startsWith("@")) {
            var fileQuery = term.substring(1).trim();
            filtered.push({ typeLabel: "HEADER", name: fileQuery ? "SEARCHING: " + fileQuery.toUpperCase() : "FILE SEARCH" });
            filtered.push({
                typeLabel: "SEARCH",
                name: "SEARCHING...",
                icon: "󰉋",
                comment: fileQuery ? "@" + fileQuery : "e.g. @report @config",
                isFileSearch: true,
                fileQuery: fileQuery
            });
            if (fileQuery) {
                root.startFileSearch(fileQuery);
            }
        } else {
            for (let i = 0; i < sourceApps.length; i++) {
                let item = sourceApps[i];
                if (fuzzyMatch(item.name, term) || fuzzyMatch(item.comment, term)) {
                    item.typeLabel = "APP";
                    filtered.push(item);
                }
            }
        }
        root.displayData = filtered;
        root.selectedIndex = 0;
    }

    function startFileSearch(query) {
        root._fileSeq++;
        fileSearchProc.command = [Theme.bin("get_apps_list"), "--search-files", query];
        fileSearchProc.running = true;
    }

    function launchSelected() {
        if (root.displayData.length > 0 && root.selectedIndex < root.displayData.length) {
            var item = root.displayData[root.selectedIndex];
            if (item.typeLabel === "HEADER")
                return;

            if (item.isWebAction) {
                Quickshell.execDetached([Theme.bin("get_apps_list"), "--web-search", item.query]);
            } else if (item.isFileSearch) {
                if (item.fileQuery) {
                    Quickshell.execDetached([Theme.bin("get_apps_list"), "--search-files", item.fileQuery]);
                }
            } else if (item.typeLabel === "FILE") {
                Quickshell.execDetached([Theme.bin("get_apps_list"), "--open-file", item.path]);
            } else if (item.typeLabel === "WEB") {
                Quickshell.execDetached(["xdg-open", item.url]);
            } else if (item.exec) {
                Quickshell.execDetached([Theme.bin("get_apps_list"), "--launch", item.name]);
                Quickshell.execDetached(["sh", "-c", item.exec]);
            } else {
                return;
            }
            AppsService.refresh();
            root.showPopup = false;
        }
    }

    Process {
        id: fileSearchProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var seq = root._fileSeq;
                try {
                    var results = JSON.parse(this.text);
                    if (!Array.isArray(results) || seq !== root._fileSeq)
                        return;

                    var items = [{ typeLabel: "HEADER", name: "FILES" }];
                    if (results.length === 0) {
                        items.push({
                            typeLabel: "SEARCH",
                            name: "NO FILES FOUND",
                            icon: "󰉋",
                            comment: "run --index-files first to build index"
                        });
                    } else {
                        for (let i = 0; i < Math.min(results.length, 50); i++) {
                            items.push({
                                typeLabel: "FILE",
                                name: results[i].name,
                                icon: "󰉋",
                                comment: results[i].path,
                                path: results[i].path
                            });
                        }
                    }
                    root.displayData = items;
                    root.selectedIndex = 0;
                } catch (e) {
                    console.warn("Apps: file search parse error:", e);
                }
            }
        }
    }

    title: "System Index"
    width: Screen.width ? Math.max(460, Math.round(Screen.width * 0.22)) : 460
    height: Screen.height ? Math.max(520, Math.round(Screen.height * 0.48)) : 520
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint
    visible: showPopup
    onVisibleChanged: {
        if (visible) {
            rebuildDisplay();
            searchField.forceActiveFocus();
        } else {
            searchField.text = "";
        }
    }
    onActiveChanged: {
        if (!active && showPopup) {
            showPopup = false;
        }
    }
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            root.showPopup = false;
            event.accepted = true;
        }
    }

    // ── Search debounce ──
    Timer {
        id: searchDebounce
        interval: 150
        onTriggered: root.rebuildDisplay()
    }

    // ── UI LAYOUT ──
    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        border.width: 2
        border.color: Theme.primary
        radius: 0

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ── Row 1: Brutalist Title Bar ──
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                color: Theme.bg
                border.width: 1
                border.color: Theme.primary

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8
                    spacing: 12

                    Text {
                        text: "󰀻"
                        color: Theme.primary
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                    }

                    Text {
                        text: "SYSTEM INDEX"
                        color: Theme.primary
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Text {
                        text: (AppsService.rawData.all_apps ? AppsService.rawData.all_apps.length : "0") + " INDEXED"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.bold: true
                    }

                    Rectangle {
                        implicitWidth: 24
                        implicitHeight: 24
                        radius: 0
                        color: closeMa.containsMouse ? Theme.error : "transparent"
                        border.width: 1
                        border.color: closeMa.containsMouse ? Theme.error : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: closeMa.containsMouse ? Theme.bg : Theme.fg
                            font.pixelSize: 10
                            font.bold: true
                        }

                        MouseArea {
                            id: closeMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.showPopup = false
                        }
                    }
                }
            }

            // ── Row 2: Search Input Block ──
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                color: Theme.surface
                border.width: 0

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 2
                    color: searchField.activeFocus ? Theme.primary : Theme.surfaceLighter
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 12
                    spacing: 12

                    Text {
                        text: ""
                        color: searchField.activeFocus ? Theme.primary : Theme.muted
                        font.pixelSize: 14
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "SEARCH APPS, !g, !yt, @files..."
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.bold: true
                            visible: searchField.text === ""
                        }

                        TextInput {
                            id: searchField
                            anchors.fill: parent
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.bold: true
                            selectByMouse: true
                            clip: true
                            onTextChanged: {
                                root.searchText = text;
                                searchDebounce.restart();
                            }
                            Keys.onPressed: (event) => {
                                if (event.key === Qt.Key_Up || (event.key === Qt.Key_K && (event.modifiers & Qt.ControlModifier))) {
                                    root.moveUp();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Down || (event.key === Qt.Key_J && (event.modifiers & Qt.ControlModifier))) {
                                    root.moveDown();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    root.launchSelected();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Escape) {
                                    root.showPopup = false;
                                    event.accepted = true;
                                }
                            }
                        }
                    }

                    Rectangle {
                        implicitWidth: 24
                        implicitHeight: 24
                        radius: 0
                        color: clearMa.containsMouse ? Theme.primary : "transparent"
                        visible: searchField.text !== ""

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            color: clearMa.containsMouse ? Theme.bg : Theme.muted
                            font.pixelSize: 14
                        }

                        MouseArea {
                            id: clearMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchField.text = "";
                                searchField.forceActiveFocus();
                            }
                        }
                    }
                }
            }

            // ── System Status States ──
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"
                visible: !AppsService.isLoaded

                Text {
                    anchors.centerIn: parent
                    text: "WAITING FOR BACKEND..."
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"
                visible: AppsService.isLoaded && root.displayData.length === 0 && root.searchText !== ""

                Text {
                    anchors.centerIn: parent
                    text: "NO MATCHES FOUND"
                    color: Theme.error
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                }
            }

            // ── Universal Index List ──
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"
                visible: AppsService.isLoaded && root.displayData.length > 0

                ListView {
                    id: listView
                    anchors.fill: parent
                    anchors.margins: 4
                    clip: true
                    model: root.displayData
                    spacing: 2
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {
                        policy: listView.contentHeight > listView.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                        contentItem: Rectangle {
                            implicitWidth: 4
                            color: Theme.primary
                            radius: 0
                        }
                    }

                    delegate: Item {
                        required property var modelData
                        required property int index

                        width: ListView.view.width - (listView.ScrollBar.vertical.visible ? 8 : 0)
                        height: modelData.typeLabel === "HEADER" ? 28 : 44

                        Rectangle {
                            anchors.fill: parent
                            color: modelData.typeLabel === "HEADER" ? "transparent" : (root.selectedIndex === index ? Theme.primary : (ma.containsMouse ? Theme.surfaceLighter : "transparent"))
                            border.width: modelData.typeLabel === "HEADER" ? 0 : 1
                            border.color: modelData.typeLabel === "HEADER" ? "transparent" : (root.selectedIndex === index ? Theme.primary : "transparent")

                            MouseArea {
                                id: ma
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: modelData.typeLabel === "HEADER" ? Qt.ArrowCursor : Qt.PointingHandCursor
                                onEntered: {
                                    if (modelData.typeLabel !== "HEADER")
                                        root.selectedIndex = index;
                                }
                                onClicked: root.launchSelected()
                            }

                            // HEADER item
                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                verticalAlignment: Text.AlignVCenter
                                text: modelData.name || ""
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.bold: true
                                visible: modelData.typeLabel === "HEADER"
                            }

                            // ITEM content (non-header)
                            Item {
                                anchors.fill: parent
                                visible: modelData.typeLabel !== "HEADER"

                                Item {
                                    id: itemIcon
                                    anchors.left: parent.left
                                    anchors.leftMargin: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 24
                                    height: 24

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.icon || "󰣇"
                                        color: root.selectedIndex === index ? Theme.bg : Theme.primary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 16
                                        visible: imgIcon.status === Image.Error || modelData.typeLabel !== "APP"
                                    }

                                    Image {
                                        id: imgIcon
                                        anchors.centerIn: parent
                                        width: 16
                                        height: 16
                                        source: modelData.typeLabel === "APP" && modelData.icon ? (modelData.icon.startsWith("/") ? "file://" + modelData.icon : "image://icon/" + modelData.icon) : ""
                                        visible: modelData.typeLabel === "APP" && status !== Image.Error
                                        sourceSize.width: 16
                                        sourceSize.height: 16
                                    }
                                }

                                Text {
                                    id: enterIndicator
                                    anchors.right: parent.right
                                    anchors.rightMargin: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "↵"
                                    visible: root.selectedIndex === index
                                    color: Theme.bg
                                    font.pixelSize: 16
                                    font.bold: true
                                    width: visible ? 16 : 0
                                }

                                Rectangle {
                                    id: typeBadge
                                    anchors.right: enterIndicator.visible ? enterIndicator.left : parent.right
                                    anchors.rightMargin: enterIndicator.visible ? 8 : 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 42
                                    height: 18
                                    color: root.selectedIndex === index ? Theme.bg : Theme.surfaceLighter
                                    border.width: 1
                                    border.color: root.selectedIndex === index ? Theme.bg : Theme.surfaceLighter
                                    radius: 0

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.typeLabel || "SYS"
                                        color: root.selectedIndex === index ? Theme.primary : Theme.fg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 9
                                        font.bold: true
                                    }
                                }

                                Item {
                                    anchors.left: itemIcon.right
                                    anchors.leftMargin: 14
                                    anchors.right: typeBadge.left
                                    anchors.rightMargin: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: modelData.comment !== "" ? 26 : 14

                                    Text {
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        text: (modelData.name || "").toUpperCase()
                                        color: root.selectedIndex === index ? Theme.bg : Theme.fg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        text: (modelData.comment || "")
                                        color: root.selectedIndex === index ? Qt.alpha(Theme.bg, 0.7) : Theme.muted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 9
                                        elide: Text.ElideRight
                                        visible: modelData.comment !== ""
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}