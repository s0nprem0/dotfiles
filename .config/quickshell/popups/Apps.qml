import "../service"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Window {
    id: root

    property bool showPopup: false
    property var displayData: []
    property string searchText: ""
    property int selectedIndex: 0
    property int _fileSeq: 0
    property int activeTab: 0
    property var bookmarks: []
    property var gitRepos: []
    property bool isFetchingRepos: false

    function buildWebUrl(query) {
        var q = query.trim();
        if (!q.startsWith("!")) return "";
        var searchQuery = "";
        var searchUrl = "";
        if (q.startsWith("!youtube")) {
            searchQuery = q.substring(9).trim();
            searchUrl = "https://www.youtube.com/results?search_query=" + encodeURIComponent(searchQuery);
        } else if (q.startsWith("!yt ")) {
            searchQuery = q.substring(4).trim();
            searchUrl = "https://www.youtube.com/results?search_query=" + encodeURIComponent(searchQuery);
        } else if (q.startsWith("!github")) {
            searchQuery = q.substring(8).trim();
            searchUrl = "https://github.com/search?q=" + encodeURIComponent(searchQuery);
        } else if (q.startsWith("!gh ")) {
            searchQuery = q.substring(4).trim();
            searchUrl = "https://github.com/search?q=" + encodeURIComponent(searchQuery);
        } else if (q.startsWith("!wikipedia")) {
            searchQuery = q.substring(11).trim();
            searchUrl = "https://en.wikipedia.org/wiki/Special:Search?search=" + encodeURIComponent(searchQuery);
        } else if (q.startsWith("!wiki")) {
            searchQuery = q.substring(6).trim();
            searchUrl = "https://en.wikipedia.org/wiki/Special:Search?search=" + encodeURIComponent(searchQuery);
        } else if (q.startsWith("!google")) {
            searchQuery = q.substring(8).trim();
            searchUrl = "https://www.google.com/search?q=" + encodeURIComponent(searchQuery);
        } else if (q.startsWith("!g ")) {
            searchQuery = q.substring(3).trim();
            searchUrl = "https://www.google.com/search?q=" + encodeURIComponent(searchQuery);
        } else {
            searchQuery = q.substring(1).trim();
            searchUrl = "https://duckduckgo.com/?q=" + encodeURIComponent(searchQuery);
        }
        return searchUrl;
    }

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

        if (root.activeTab === 0) {
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
            } else {
                for (let i = 0; i < sourceApps.length; i++) {
                    let item = sourceApps[i];
                    if (fuzzyMatch(item.name, term) || fuzzyMatch(item.comment, term)) {
                        item.typeLabel = "APP";
                        filtered.push(item);
                    }
                }
            }
        } else if (root.activeTab === 1) {
            if (term.startsWith("!")) {
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
                    isWebAction: true,
                    url: buildWebUrl(term)
                });
            }
        } else if (root.activeTab === 2) {
            var fileQuery = term.startsWith("@") ? term.substring(1).trim() : term;
            filtered.push({ typeLabel: "HEADER", name: fileQuery ? "SEARCHING: " + fileQuery.toUpperCase() : "FILE SEARCH" });
            if (fileQuery) {
                filtered.push({
                    typeLabel: "SEARCH",
                    name: "SEARCHING...",
                    icon: "󰉋",
                    comment: "@" + fileQuery,
                    isFileSearch: true,
                    fileQuery: fileQuery
                });
                root.startFileSearch(fileQuery);
            }
        } else if (root.activeTab === 3) {
            if (term === "" || term.startsWith("#")) {
                var gitQuery = term.startsWith("#") ? term.substring(1).trim() : "";
                if (root.isFetchingRepos) {
                    filtered.push({ typeLabel: "HEADER", name: "LOADING REPOS..." });
                } else if (root.gitRepos.length > 0) {
                    filtered.push({ typeLabel: "HEADER", name: "YOUR GIT REPOS" });
                    for (let i = 0; i < root.gitRepos.length; i++) {
                        let repo = root.gitRepos[i];
                        if (gitQuery === "" || repo.name.toLowerCase().includes(gitQuery.toLowerCase()) || (repo.description && repo.description.toLowerCase().includes(gitQuery.toLowerCase()))) {
                            filtered.push({
                                typeLabel: "GIT_REPO",
                                name: repo.name,
                                icon: "󰊢",
                                comment: repo.description || repo.html_url,
                                data: repo
                            });
                        }
                    }
                } else {
                    filtered.push({ typeLabel: "HEADER", name: "CLICK TO FETCH REPOS" });
                    filtered.push({
                        typeLabel: "FETCH_REPOS",
                        name: "FETCH GITHUB REPOS",
                        icon: "󰊢",
                        comment: "set GITHUB_TOKEN env var first"
                    });
                }
            }
        } else if (root.activeTab === 4) {
            var bookmarkQuery = term.startsWith("~") ? term.substring(1).trim() : term;
            var matchingBookmarks = [];
            for (let i = 0; i < root.bookmarks.length; i++) {
                if (bookmarkQuery === "" || root.bookmarks[i].url.toLowerCase().includes(bookmarkQuery.toLowerCase()) || root.bookmarks[i].name.toLowerCase().includes(bookmarkQuery.toLowerCase())) {
                    matchingBookmarks.push(root.bookmarks[i]);
                }
            }
            if (matchingBookmarks.length > 0) {
                filtered.push({ typeLabel: "HEADER", name: "BOOKMARKS" });
                for (let i = 0; i < matchingBookmarks.length; i++) {
                    filtered.push({
                        typeLabel: "BOOKMARK",
                        name: matchingBookmarks[i].name,
                        icon: "󰌹",
                        comment: matchingBookmarks[i].url,
                        data: matchingBookmarks[i]
                    });
                }
            }
            if (bookmarkQuery !== "") {
                filtered.push({
                    typeLabel: "ADD_BOOKMARK",
                    name: "ADD BOOKMARK",
                    icon: "󰅕",
                    comment: bookmarkQuery,
                    url: bookmarkQuery
                });
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
                Quickshell.execDetached(["xdg-open", item.url]);
                Quickshell.execDetached(["hyprctl", "dispatch", "workspace", "1"]);
            } else if (item.typeLabel === "GIT_REPO") {
                Quickshell.execDetached(["xdg-open", item.data.html_url]);
                Quickshell.execDetached(["hyprctl", "dispatch", "workspace", "1"]);
            } else if (item.typeLabel === "BOOKMARK") {
                Quickshell.execDetached(["xdg-open", item.data.url]);
                Quickshell.execDetached(["hyprctl", "dispatch", "workspace", "1"]);
            } else if (item.typeLabel === "FETCH_REPOS") {
                root.fetchGitRepos();
            } else if (item.typeLabel === "ADD_BOOKMARK") {
                Quickshell.execDetached([Theme.bin("get_apps_list"), "--add-bookmark", item.url]);
            } else if (item.typeLabel === "FILE") {
                Quickshell.execDetached(["xdg-open", item.path]);
            } else if (item.isIndexAction) {
                Quickshell.execDetached([Theme.bin("get_apps_list"), "--index-files"]);
                var idx = root.selectedIndex;
                var display = root.displayData.slice();
                display[idx] = {
                    typeLabel: "INDEX",
                    name: "INDEXING...",
                    icon: "󰇚",
                    comment: "scanning home directory, this may take a moment..."
                };
                root.displayData = display;
            } else if (item.exec) {
                Quickshell.execDetached([Theme.bin("get_apps_list"), "--launch", item.name]);
                Quickshell.execDetached(["sh", "-c", item.exec]);
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
                            typeLabel: "INDEX",
                            name: "INDEX FILES NOW",
                            icon: "󰇚",
                            comment: "scan home directory with fd (excludes .git, node_modules, .cache, target)",
                            isIndexAction: true
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
            root.activeTab = 0;
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

    function loadBookmarks() {
        getBookmarksProc.command = [Theme.bin("get_apps_list"), "--get-bookmarks"];
        getBookmarksProc.running = true;
    }

    function loadGitRepos() {
        getGitReposProc.command = [Theme.bin("get_apps_list"), "--list-repos"];
        getGitReposProc.running = true;
    }

    function fetchGitRepos() {
        if (root.isFetchingRepos) return;
        root.isFetchingRepos = true;
        fetchReposProc.command = [Theme.bin("get_apps_list"), "--fetch-repos"];
        fetchReposProc.running = true;
    }

    Process {
        id: getBookmarksProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.bookmarks = JSON.parse(this.text) || [];
                } catch (e) {
                    console.warn("Apps: bookmark parse error:", e);
                }
            }
        }
    }

    Process {
        id: getGitReposProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.gitRepos = JSON.parse(this.text) || [];
                } catch (e) {
                    console.warn("Apps: git repos parse error:", e);
                }
            }
        }
    }

    Process {
        id: fetchReposProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.isFetchingRepos = false;
                root.loadGitRepos();
            }
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
                            text: root.activeTab === 0 ? "SEARCH APPS, !g, !yt, @files..." : (root.activeTab === 1 ? "SEARCH THE WEB..." : "SEARCH FILES...")
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
                                updateTabFromText();
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
                                } else if (event.key === Qt.Key_Tab) {
                                    cycleTab();
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

            // ── Row 2.5: Tab Switcher ──
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                color: Theme.surface
                visible: AppsService.isLoaded

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    spacing: 0

                    Item {
                        Layout.fillHeight: true
                        Layout.preferredWidth: 60
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 2
                            color: root.activeTab === 0 ? Theme.primary : "transparent"
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "APPS"
                            color: root.activeTab === 0 ? Theme.primary : Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var t = searchField.text.replace(/^[!@]/, "");
                                searchField.text = t;
                                root.activeTab = 0;
                                searchField.forceActiveFocus();
                            }
                        }
                    }
                    Item {
                        Layout.fillHeight: true
                        Layout.preferredWidth: 60
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 2
                            color: root.activeTab === 1 ? Theme.primary : "transparent"
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "WEB"
                            color: root.activeTab === 1 ? Theme.primary : Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var t = searchField.text.replace(/^[!@]/, "");
                                searchField.text = "!" + t;
                                root.activeTab = 1;
                                searchField.forceActiveFocus();
                            }
                        }
                    }
                    Item {
                        Layout.fillHeight: true
                        Layout.preferredWidth: 60
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 2
                            color: root.activeTab === 2 ? Theme.primary : "transparent"
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "FILES"
                            color: root.activeTab === 2 ? Theme.primary : Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var t = searchField.text.replace(/^[!@]/, "");
                                searchField.text = "@" + t;
                                root.activeTab = 2;
                                searchField.forceActiveFocus();
                            }
                        }
                    }
                    Item {
                        Layout.fillHeight: true
                        Layout.preferredWidth: 60
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 2
                            color: root.activeTab === 3 ? Theme.primary : "transparent"
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "GIT"
                            color: root.activeTab === 3 ? Theme.primary : Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var t = searchField.text.replace(/^[!@]/, "");
                                searchField.text = "#" + t;
                                root.activeTab = 3;
                                searchField.forceActiveFocus();
                            }
                        }
                    }
                    Item {
                        Layout.fillHeight: true
                        Layout.preferredWidth: 60
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 2
                            color: root.activeTab === 4 ? Theme.primary : "transparent"
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "BMK"
                            color: root.activeTab === 4 ? Theme.primary : Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var t = searchField.text.replace(/^[!@]/, "");
                                searchField.text = "~" + t;
                                root.activeTab = 4;
                                searchField.forceActiveFocus();
                            }
                        }
                    }
                }
            }

            // ── Row 2.5: Active Windows ──
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                color: Theme.surface
                visible: Hyprland.toplevels.length > 0

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 2

                    Text {
                        text: "ACTIVE WINDOWS (" + Hyprland.toplevels.length + ")"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        font.bold: true
                        leftPadding: 6
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        orientation: ListView.Horizontal
                        spacing: 4
                        clip: true
                        model: Hyprland.toplevels

                        ScrollBar.horizontal: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            contentItem: Rectangle {
                                implicitHeight: 3
                                color: Theme.primary
                            }
                        }

                        delegate: Item {
                            required property var modelData

                            width: 36
                            height: ListView.view.height

                            Rectangle {
                                anchors.fill: parent
                                color: Theme.surfaceLighter
                                border.width: winMa.containsMouse ? 1 : 0
                                border.color: winMa.containsMouse ? Theme.primary : "transparent"

                                ScreencopyView {
                                    id: scrCap
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    captureSource: modelData
                                    live: true
                                    visible: hasContent
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰇄"
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    visible: !scrCap.hasContent
                                }

                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    width: 14
                                    height: 14
                                    color: Theme.primary
                                    visible: modelData.workspace !== undefined

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.workspace ? modelData.workspace.id.toString() : ""
                                        color: Theme.bg
                                        font.pixelSize: 7
                                        font.bold: true
                                    }
                                }

                                MouseArea {
                                    id: winMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        modelData.activate();
                                        root.showPopup = false;
                                    }
                                }
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

    function getTabHint() {
        if (root.activeTab === 0) return "SEARCH APPS, !g, !yt, @files, #repos, ~bookmarks...";
        if (root.activeTab === 1) return "SEARCH THE WEB WITH !g, !yt...";
        if (root.activeTab === 2) return "SEARCH FILES WITH @...";
        if (root.activeTab === 3) return "SEARCH GIT REPOS WITH #...";
        return "SEARCH BOOKMARKS WITH ~...";
    }

    function updateTabFromText() {
        var t = searchField.text;
        if (t.startsWith("!")) root.activeTab = 1;
        else if (t.startsWith("@")) root.activeTab = 2;
        else if (t.startsWith("#")) root.activeTab = 3;
        else if (t.startsWith("~")) root.activeTab = 4;
        else root.activeTab = 0;
    }

    function cycleTab() {
        var t = searchField.text.replace(/^[!@#~]/, "");
        root.activeTab = (root.activeTab + 1) % 5;
        if (root.activeTab === 0) searchField.text = t;
        else if (root.activeTab === 1) searchField.text = "!" + t;
        else if (root.activeTab === 2) searchField.text = "@" + t;
        else if (root.activeTab === 3) searchField.text = "#" + t;
        else searchField.text = "~" + t;
    }
}