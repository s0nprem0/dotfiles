import "../service"
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell

Window {
    id: root

    title: "System Index"
    width: 460
    height: 520
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint

    property bool showPopup: false
    visible: showPopup

    property var displayData: []
    property string searchText: ""
    property int selectedIndex: 0

    onVisibleChanged: {
        if (visible) {
            rebuildDisplay();
            searchField.forceActiveFocus();
        } else {
            searchField.text = "";
        }
    }

    // ── NAVIGATION LOGIC (Fixes text cursor jumping) ──
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

    // ── DATA AGGREGATION ENGINE ──
    function rebuildDisplay() {
        var term = root.searchText.trim();
        var sourceApps = AppsService.rawData.all_apps || [];
        var mostUsed = AppsService.rawData.most_used || [];
        var webHistory = AppsService.rawData.web_history || [];
        var fileHistory = AppsService.rawData.file_history || [];
        var filtered = [];

        if (term === "") {
            for (let i = 0; i < mostUsed.length; i++) {
                let item = Object.assign({}, mostUsed[i]);
                item.typeLabel = "APP";
                filtered.push(item);
            }
            for (let i = 0; i < Math.min(fileHistory.length, 5); i++) {
                let item = Object.assign({}, fileHistory[i]);
                item.typeLabel = "FILE";
                item.icon = "󰈔";
                item.comment = item.path;
                filtered.push(item);
            }
            for (let i = 0; i < Math.min(webHistory.length, 5); i++) {
                let item = Object.assign({}, webHistory[i]);
                item.typeLabel = "WEB";
                item.name = item.query;
                item.icon = "󰖟";
                item.comment = item.engine.toUpperCase();
                filtered.push(item);
            }
        } else if (term.startsWith("!")) {
            filtered.push({
                typeLabel: "SEARCH",
                name: "EXECUTE WEB QUERY",
                icon: "󰖟",
                comment: term,
                query: term,
                isWebAction: true
            });
        } else {
            var lowerTerm = term.toLowerCase();
            for (let i = 0; i < sourceApps.length; i++) {
                let item = sourceApps[i];
                if ((item.name || "").toLowerCase().indexOf(lowerTerm) >= 0 ||
                    (item.comment && item.comment.toLowerCase().indexOf(lowerTerm) >= 0)) {
                    item.typeLabel = "APP";
                    filtered.push(item);
                }
            }
        }

        root.displayData = filtered;
        root.selectedIndex = 0;
    }

    // ── LAUNCH ROUTER ──
    function launchSelected() {
        if (root.displayData.length > 0 && root.selectedIndex < root.displayData.length) {
            var item = root.displayData[root.selectedIndex];

            if (item.isWebAction) {
                Quickshell.execDetached([Theme.bin("get_apps_list"), "--web-search", item.query]);
            } else if (item.typeLabel === "FILE") {
                Quickshell.execDetached([Theme.bin("get_apps_list"), "--open-file", item.path]);
            } else if (item.typeLabel === "WEB") {
                Quickshell.execDetached(["xdg-open", item.url]);
            } else {
                Quickshell.execDetached([Theme.bin("get_apps_list"), "--launch", item.name]);
                Quickshell.execDetached(["sh", "-c", item.exec]);
            }

            AppsService.refresh();
            root.showPopup = false;
        }
    }

    // Global Window fallbacks
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            root.showPopup = false;
            event.accepted = true;
        }
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

                    Text { text: "󰀻"; color: Theme.primary; font.family: Theme.fontFamily; font.pixelSize: 13 }

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
                        implicitWidth: 24; implicitHeight: 24; radius: 0
                        color: closeMa.containsMouse ? Theme.error : "transparent"
                        border.width: 1; border.color: closeMa.containsMouse ? Theme.error : "transparent"

                        Text {
                            anchors.centerIn: parent; text: "✕";
                            color: closeMa.containsMouse ? Theme.bg : Theme.fg;
                            font.pixelSize: 10; font.bold: true
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

                    Text { text: ""; color: searchField.activeFocus ? Theme.primary : Theme.muted; font.pixelSize: 14 }

                    StackLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Text {
                            verticalAlignment: Text.AlignVCenter
                            text: "SEARCH APPS, TYPE !g OR !yt..."
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.bold: true
                            visible: searchField.text === ""
                        }

                        TextInput {
                            id: searchField
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.bold: true
                            selectByMouse: true
                            clip: true

                            onTextChanged: {
                                root.searchText = text
                                root.rebuildDisplay()
                            }

                            // PERFECTED UX: Intercept navigation entirely so cursor doesn't jump
                            Keys.onPressed: (event) => {
                                if (event.key === Qt.Key_Up || (event.key === Qt.Key_K && (event.modifiers & Qt.ControlModifier))) {
                                    root.moveUp();
                                    event.accepted = true; // Stops text cursor movement
                                } else if (event.key === Qt.Key_Down || (event.key === Qt.Key_J && (event.modifiers & Qt.ControlModifier))) {
                                    root.moveDown();
                                    event.accepted = true; // Stops text cursor movement
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
                        implicitWidth: 24; implicitHeight: 24; radius: 0
                        color: clearMa.containsMouse ? Theme.primary : "transparent"
                        visible: searchField.text !== ""

                        Text {
                            anchors.centerIn: parent; text: "󰅖"
                            color: clearMa.containsMouse ? Theme.bg : Theme.muted
                            font.pixelSize: 14
                        }
                        MouseArea {
                            id: clearMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchField.text = ""
                                searchField.forceActiveFocus()
                            }
                        }
                    }
                }
            }

            // ── System Status States ──
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true; color: "transparent"
                visible: !AppsService.isLoaded
                Text { anchors.centerIn: parent; text: "WAITING FOR BACKEND..."; color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: 11; font.bold: true }
            }

            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true; color: "transparent"
                visible: AppsService.isLoaded && root.displayData.length === 0 && root.searchText !== ""
                Text { anchors.centerIn: parent; text: "NO MATCHES FOUND"; color: Theme.error; font.family: Theme.fontFamily; font.pixelSize: 11; font.bold: true }
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

                    header: Item {
                        width: ListView.view.width
                        height: root.searchText === "" && root.displayData.length > 0 ? 28 : 0
                        visible: height > 0

                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            verticalAlignment: Text.AlignVCenter
                            text: "FREQUENTLY USED"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.bold: true
                        }
                    }

                    delegate: Item {
                        required property var modelData
                        required property int index

                        width: ListView.view.width
                        height: 44

                        Rectangle {
                            anchors.fill: parent
                            color: root.selectedIndex === index ? Theme.primary : (ma.containsMouse ? Theme.surfaceLighter : "transparent")
                            border.width: 1
                            border.color: root.selectedIndex === index ? Theme.primary : "transparent"

                            MouseArea {
                                id: ma
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.selectedIndex = index
                                onClicked: root.launchSelected()
                            }

                            // PERFECTED UX: Strict Grid Anchoring instead of RowLayout
                            // 1. Icon Anchored Left
                            Text {
                                id: itemIcon
                                anchors.left: parent.left
                                anchors.leftMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.icon || "󰣇"
                                color: root.selectedIndex === index ? Theme.bg : Theme.primary
                                font.family: Theme.fontFamily
                                font.pixelSize: 16
                                width: 24
                                horizontalAlignment: Text.AlignHCenter
                            }

                            // 2. The "Enter" Indicator Anchored Far Right
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
                                width: visible ? 16 : 0 // Collapses to 0 width when hidden so badge doesn't shift
                            }

                            // 3. The Classification Badge Anchored to the left of the Enter Indicator
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

                            // 4. The Text Block Anchored securely between the Icon and the Badge
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
