import "../service"
import "../service/OsdUtils.js" as OsdUtils
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    readonly property string statePath: "file://" + Theme.cacheDir + "/osd_state.json"
    property string message: ""
    property string kind: "info"
    property bool visibleNow: false
    required property var audioModuleRef

    property string mediaArtUrl: ""

    function handleArtUrl(url) {
        if (!url) {
            mediaArtUrl = "";
            return;
        }
        if (url.indexOf("http://") === 0 || url.indexOf("https://") === 0) {
            osdArtCache.ensureCached(url);
        } else {
            mediaArtUrl = url;
        }
    }

    function getIconColor(msg) {
        var lower = msg.toLowerCase();
        if (lower.includes("mute"))
            return Theme.error;

        if (lower.includes("brightness") || lower.includes("volume"))
            return Theme.primary;

        return Theme.fg;
    }

    function defaultState() {
        return {
            "visible": false,
            "text": "",
            "kind": "info",
            "timeout_ms": 1200
        };
    }

    function readState() {
        try {
            var raw = stateFile.text();
            if (!raw || raw.trim() === "")
                return defaultState();

            var parsed = JSON.parse(raw);
            return {
                "visible": parsed.visible !== false,
                "text": String(parsed.text ?? ""),
                "kind": String(parsed.kind ?? "info"),
                "timeout_ms": parsed.timeout_ms ?? 1200
            };
        } catch (e) {
            return defaultState();
        }
    }

    function refreshState() {
        var state = readState();
        message = state.text;
        kind = state.kind;
        visibleNow = state.visible && state.text.length > 0;
        if (visibleNow) {
            hideTimer.interval = state.timeout_ms || 1200;
            hideTimer.restart();
        } else {
            hideTimer.stop();
        }
    }

    Timer {
        id: hideTimer

        interval: 1200
        repeat: false
        onTriggered: {
            root.visibleNow = false;
        }
    }

    FileView {
        id: stateFile

        path: root.statePath
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.refreshState()
    }

    Connections {
        target: audioModuleRef
        function onArtUrlChanged() {
            root.handleArtUrl(audioModuleRef ? audioModuleRef.artUrl : "");
        }
    }

    onAudioModuleRefChanged: {
        if (audioModuleRef)
            handleArtUrl(audioModuleRef.artUrl);
    }

    ArtCache {
        id: osdArtCache
        cachePrefix: "osd_art_"
        onCacheReady: function(url, localPath) {
            if (url === osdArtCache.pendingUrl)
                root.mediaArtUrl = localPath;
        }
    }

    // Removed Variants model to prevent duplicate windows on multiple monitors
    PanelWindow {
        id: win

        property bool isShown: root.visibleNow
        property real animTopMargin: -50
        property real animOpacity: 0

        // Bind directly to the primary screen to ensure only ONE OSD exists
        screen: Quickshell.primaryScreen
        onIsShownChanged: {
            if (isShown) {
                exitAnim.stop();
                introAnim.start();
            } else {
                introAnim.stop();
                exitAnim.start();
            }
        }
        color: "transparent"
        exclusionMode: PanelWindow.ExclusionMode.Ignore
        WlrLayershell.namespace: "osd"
        visible: root.visibleNow || exitAnim.running
        implicitWidth: {
            var base = 200;
            if (OsdUtils.getPercentage(root.message) === -1)
                base = fallbackLabel.implicitWidth + (fallbackIcon.visible ? fallbackIcon.implicitWidth + 6 : 0) + 18;

            if (win.isShown && audioModuleRef && audioModuleRef.hasPlayer)
                base = Math.max(base, 260);

            return base;
        }
        implicitHeight: mainLayout.implicitHeight + 12
        Component.onCompleted: {
            if (root.visibleNow) {
                animTopMargin = 5;
                animOpacity = 1;
            }
        }

        anchors {
            top: true
            left: true
        }

        margins {
            top: win.animTopMargin
            left: 30
        }

        ParallelAnimation {
            id: introAnim

            NumberAnimation {
                target: win
                property: "animTopMargin"
                from: -50
                to: 5
                duration: 120
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: win
                property: "animOpacity"
                from: 0
                to: 1
                duration: 120
                easing.type: Easing.OutCubic
            }

        }

        ParallelAnimation {
            id: exitAnim

            NumberAnimation {
                target: win
                property: "animTopMargin"
                from: 5
                to: -50
                duration: 100
                easing.type: Easing.InCubic
            }

            NumberAnimation {
                target: win
                property: "animOpacity"
                from: 1
                to: 0
                duration: 100
                easing.type: Easing.InCubic
            }

        }

        Rectangle {
            anchors.fill: parent
            opacity: win.animOpacity
            color: Qt.alpha(Theme.bg, 0.85)
            border.width: 1
            border.color: root.kind === "good" ? Theme.primary : root.kind === "bad" ? Theme.error : root.kind === "warn" ? Theme.warning : Theme.primary
            radius: 0
            antialiasing: false

            Column {
                id: mainLayout

                anchors.centerIn: parent
                spacing: 4
                width: parent.width - 18

                Row {
                    id: osdStatusRow

                    spacing: 6
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: OsdUtils.getPercentage(root.message) !== -1

                    Text {
                        text: OsdUtils.getIcon(root.message)
                        color: root.getIconColor(root.message)
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        renderType: Text.NativeRendering
                        anchors.verticalCenter: parent.verticalCenter
                        visible: text !== ""
                    }

                    Text {
                        text: OsdUtils.getPrefix(root.message)
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        renderType: Text.NativeRendering
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Row {
                        id: blockSlider

                        property int totalBlocks: 15
                        property double currentVal: OsdUtils.getPercentage(root.message) / 100

                        spacing: 1
                        height: 4
                        anchors.verticalCenter: parent.verticalCenter

                        Repeater {
                            model: blockSlider.totalBlocks

                            delegate: Rectangle {
                                height: parent.height
                                width: 5
                                color: (index < Math.round(blockSlider.currentVal * blockSlider.totalBlocks)) ? Theme.primary : Theme.surfaceLighter
                            }

                        }

                    }

                    Text {
                        text: OsdUtils.getPercentText(root.message)
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        renderType: Text.NativeRendering
                        anchors.verticalCenter: parent.verticalCenter
                    }

                }

                Row {
                    spacing: 6
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: OsdUtils.getPercentage(root.message) === -1

                    Text {
                        id: fallbackIcon

                        text: OsdUtils.getIcon(root.message)
                        color: root.getIconColor(root.message)
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        renderType: Text.NativeRendering
                        visible: text !== ""
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        id: fallbackLabel

                        text: root.message
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        renderType: Text.NativeRendering
                        anchors.verticalCenter: parent.verticalCenter
                    }

                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.primary
                    opacity: 0.3
                    visible: win.isShown && audioModuleRef && audioModuleRef.hasPlayer
                }

                Row {
                    id: mediaRow
                    visible: win.isShown && audioModuleRef && audioModuleRef.hasPlayer
                    spacing: 6
                    width: parent.width

                    Rectangle {
                        width: 24
                        height: 24
                        color: Theme.surface
                        clip: true

                        Image {
                            id: artImg
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            source: root.mediaArtUrl
                            asynchronous: true
                            cache: true
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "󰎆"
                            color: Theme.primary
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            visible: artImg.status === Image.Error || !root.mediaArtUrl
                            renderType: Text.NativeRendering
                        }

                    }

                    Column {
                        width: parent.width - 30
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            width: parent.width
                            text: audioModuleRef ? audioModuleRef.title || "Unknown Track" : ""
                            color: Theme.primary
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.bold: true
                            elide: Text.ElideRight
                            renderType: Text.NativeRendering
                        }

                        Row {
                            spacing: 4

                            Text {
                                text: audioModuleRef ? audioModuleRef.artist || "" : ""
                                width: parent.parent.width - 10
                                color: Theme.fg
                                opacity: 0.6
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                elide: Text.ElideRight
                                renderType: Text.NativeRendering
                            }

                            Rectangle {
                                width: 4
                                height: 4
                                anchors.verticalCenter: parent.verticalCenter
                                color: audioModuleRef && audioModuleRef.playerStatus === "Playing" ? Theme.green : Theme.warning
                                visible: audioModuleRef && audioModuleRef.playerStatus !== ""
                            }

                        }

                    }

                }

            }

        }

    }

}
