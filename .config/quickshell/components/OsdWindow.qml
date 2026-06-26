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
    property var osdMedia: null
    property var osdMediaSources: []
    property string osdCurrentMediaSource: ""

    function osdMediaSourceIndex() {
        var srcLen = root.osdMediaSources.length;
        for (var i = 0; i < srcLen; i++) {
            if (root.osdMediaSources[i].name === root.osdCurrentMediaSource)
                return i;

        }
        return -1;
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
            if (message.includes("volume") && !root.osdMedia) {
                checkAudioStatusProc.running = false;
                checkAudioStatusProc.running = true;
            } else if (!message.includes("volume")) {
                root.osdMedia = null;
                root.osdMediaSources = [];
                root.osdCurrentMediaSource = "";
            }
        } else {
            hideTimer.stop();
            root.osdMedia = null;
            root.osdMediaSources = [];
            root.osdCurrentMediaSource = "";
        }
    }

    Timer {
        id: hideTimer

        interval: 1200
        repeat: false
        onTriggered: {
            root.visibleNow = false;
            root.osdMedia = null;
            root.osdMediaSources = [];
            root.osdCurrentMediaSource = "";
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

    Process {
        id: checkAudioStatusProc

        command: [Theme.bin("get_audio_status")]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    root.osdMedia = data.media || null;
                    root.osdMediaSources = data.media_sources || [];
                    root.osdCurrentMediaSource = data.current_media_source || "";
                } catch (e) {
                    root.osdMedia = null;
                    root.osdMediaSources = [];
                    root.osdCurrentMediaSource = "";
                }
            }
        }

    }

    // Single PanelWindow — OSD shows on the focused monitor
    PanelWindow {
        id: win

        property bool isShown: root.visibleNow

        function getTargetScreen() {
            if (DisplayService.primaryMonitorId) {
                var monitor = DisplayService.getMonitor(DisplayService.primaryMonitorId);
                if (monitor && !monitor.disabled) {
                    return monitor;
                }
            }
            if (Quickshell.primaryScreen) return Quickshell.primaryScreen;
            return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
        }

        screen: getTargetScreen()
        property real animTopMargin: -50
        property real animOpacity: 0
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
            if (OsdUtils.getPercentage(root.message) !== -1)
                return 200;

            return fallbackLabel.implicitWidth + (fallbackIcon.visible ? fallbackIcon.implicitWidth + 6 : 0) + 18;
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
                    visible: blockSlider.percentage !== -1

                    Text {
                        text: OsdUtils.getIcon(root.message)
                        color: root.getIconColor(root.message)
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMd
                        renderType: Text.NativeRendering
                        anchors.verticalCenter: parent.verticalCenter
                        visible: text !== ""
                    }

                    Text {
                        text: OsdUtils.getPrefix(root.message)
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                        renderType: Text.NativeRendering
                        anchors.verticalCenter: parent.verticalCenter
                    }

Row {
                    id: blockSlider

                    property int totalBlocks: 15
                    property int percentage: OsdUtils.getPercentage(root.message)
                    property double currentVal: percentage !== -1 ? percentage / 100 : 0

                    spacing: 1
                    height: 4
                    anchors.verticalCenter: parent.verticalCenter
                    visible: percentage !== -1

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
                        font.pixelSize: Theme.fontSizeSm
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
                        font.pixelSize: Theme.fontSizeMd
                        renderType: Text.NativeRendering
                        visible: text !== ""
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        id: fallbackLabel

                        text: root.message
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                        renderType: Text.NativeRendering
                        anchors.verticalCenter: parent.verticalCenter
                    }

                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.primary
                    opacity: 0.3
                    visible: root.osdMedia !== null && root.message.includes("volume")
                }

                Row {
                    width: parent.width
                    spacing: 6
                    visible: root.osdMedia !== null && root.message.includes("volume")
                    anchors.horizontalCenter: parent.horizontalCenter

                    Rectangle {
                        width: 18
                        height: 18
                        color: Theme.surface
                        clip: true
                        anchors.verticalCenter: parent.verticalCenter

                        Image {
                            id: artImage

                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            source: (root.osdMedia && root.osdMedia.art_url) ? root.osdMedia.art_url : ""
                            asynchronous: true
                            visible: source.toString() !== ""
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "󰎆"
                            color: Theme.primary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            visible: !artImage.visible
                            renderType: Text.NativeRendering
                        }

                    }

                    Column {
                        width: parent.width - 24
                        spacing: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Row {
                            width: parent.width
                            spacing: 4

                            Text {
                                width: parent.width - sourceIndicator.implicitWidth - 4
                                text: root.osdMedia ? root.osdMedia.title : ""
                                color: Theme.primary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeXs
                                font.bold: true
                                elide: Text.ElideRight
                                renderType: Text.NativeRendering
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Row {
                                id: sourceIndicator

                                spacing: 2
                                anchors.verticalCenter: parent.verticalCenter
                                visible: root.osdMediaSources.length > 1

                                Repeater {
                                    model: root.osdMediaSources

                                    delegate: Rectangle {
                                        width: 3
                                        height: 3
                                        color: index === root.osdMediaSourceIndex() ? Theme.primary : Theme.surfaceLighter
                                        border.width: 1
                                        border.color: Theme.primary
                                        opacity: index === root.osdMediaSourceIndex() ? 1 : 0.55
                                    }

                                }

                            }

                        }

                        Text {
                            width: parent.width
                            text: root.osdMedia ? (root.osdMedia.artist ? root.osdMedia.artist + " • " + root.osdMedia.player : root.osdMedia.player) : ""
                            color: Theme.primary
                            opacity: 0.6
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXxs
                            elide: Text.ElideRight
                            renderType: Text.NativeRendering
                        }

                    }

                }

            }

        }

    }

}
