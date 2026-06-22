import "../../service"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Rectangle {
    id: root

    property string wallpaperPath: ""
    property string currentMode: "wallpaper"
    property string modeName: ""
    property var presets: []

    signal closeSettings()

    color: "transparent"

    function applyWallpaper(path) {
        var absPath = Quickshell.env("HOME") + "/.cache/quickshell/current_wallpaper";
        root.wallpaperPath = path;
        Quickshell.execDetached(["sh", "-c",
            "readlink -f <<< \"" + path.replace(/"/g, '\\"') + "\" > " + absPath + " && " +
            Theme.home + "/.config/hypr/scripts/wallpaper.sh \"" + path.replace(/"/g, '\\"') + "\""]);
        root.currentMode = "wallpaper";
        root.modeName = "";
    }

    function applyPreset(name) {
        Quickshell.execDetached([Theme.bin("presetctl"), "apply", name]);
        root.currentMode = "preset";
        root.modeName = name;
    }

    function refreshPresets() {
        presetLister.running = true;
    }

    onVisibleChanged: {
        if (visible) {
            refreshPresets();
            currentProc.running = true;
        }
    }

    property bool pickWallpaperRequested: false

    Process {
        id: wallpaperPicker
        command: ["zenity", "--file-selection", "--file-filter=*.png;*.jpg;*.jpeg;*.gif;*.bmp;*.webp", "--title=Choose Wallpaper", "--filename=" + Theme.home + "/Pictures/"]
        running: root.pickWallpaperRequested
        stdout: StdioCollector {
            onStreamFinished: {
                root.pickWallpaperRequested = false;
                var path = this.text.trim();
                if (path.length > 0)
                    root.applyWallpaper(path);
            }
        }
    }

    function pickWallpaper() {
        root.pickWallpaperRequested = true;
    }

    Process {
        id: presetLister
        command: [Theme.bin("presetctl"), "list"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    if (Array.isArray(data))
                        root.presets = data;
                } catch (e) {}
            }
        }
    }

    Process {
        id: currentProc
        command: [Theme.bin("presetctl"), "current"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    if (data && data.name && data.name !== "") {
                        root.currentMode = "preset";
                        root.modeName = data.name;
                    } else {
                        root.currentMode = "wallpaper";
                        root.modeName = "";
                    }
                } catch (e) {
                    root.currentMode = "wallpaper";
                    root.modeName = "";
                }
            }
        }
    }

    FileView {
        id: wallpaperWatcher
        path: "file://" + Theme.home + "/.cache/quickshell/current_wallpaper"
        watchChanges: true
        onLoaded: {
            var val = wallpaperWatcher.text().trim();
            if (val.length > 0)
                root.wallpaperPath = val;
        }
        onFileChanged: reload()
        Component.onCompleted: reload()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        // ── Current Wallpaper ──
        Text {
            text: "CURRENT WALLPAPER"
            font.family: Theme.fontFamily
            font.pixelSize: 9
            color: Theme.primary
            font.bold: true
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            color: Theme.bg
            border.width: 1
            border.color: Theme.primary
            clip: true

            Image {
                anchors.fill: parent
                source: root.wallpaperPath ? "file://" + root.wallpaperPath : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 28
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.85) }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 6

                    Text {
                        text: root.currentMode === "preset" ? "Preset: " + root.modeName : "Wallpaper"
                        color: Theme.primary
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        font.bold: true
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Row {
                        spacing: 3
                        anchors.verticalCenter: parent.verticalCenter

                        Repeater {
                            model: [Theme.bg, Theme.surface, Theme.surfaceLighter, Theme.primary, Theme.fg, Theme.muted]
                            delegate: Rectangle {
                                width: 8; height: 8; color: modelData
                            }
                        }
                    }
                }
            }
        }

        // ── Browse Button ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            color: browseMa.containsMouse ? Theme.primary : Theme.surface
            border.width: 1
            border.color: Theme.primary

            Text {
                anchors.centerIn: parent
                text: "󰉋  Browse Wallpaper"
                color: browseMa.containsMouse ? Theme.bg : Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 9
                font.bold: true
            }

            MouseArea {
                id: browseMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.pickWallpaper()
            }
        }

        // ── Divider ──
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.alpha(Theme.primary, 0.2)
        }

        // ── Presets ──
        Text {
            text: "PRESETS"
            font.family: Theme.fontFamily
            font.pixelSize: 9
            color: Theme.primary
            font.bold: true
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ListView {
                id: presetList
                model: root.presets
                spacing: 4

                header: Rectangle {
                    width: presetList.width
                    height: 28
                    color: autoMa.containsMouse ? Theme.primary : (root.currentMode === "wallpaper" ? Qt.alpha(Theme.primary, 0.15) : "transparent")
                    border.width: 1
                    border.color: root.currentMode === "wallpaper" ? Theme.primary : Qt.alpha(Theme.primary, 0.3)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        Text {
                            text: "󰸉"
                            color: root.currentMode === "wallpaper" || autoMa.containsMouse ? (autoMa.containsMouse ? Theme.bg : Theme.primary) : Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }

                        Text {
                            text: "Auto (wallpaper-based)"
                            color: root.currentMode === "wallpaper" || autoMa.containsMouse ? (autoMa.containsMouse ? Theme.bg : Theme.primary) : Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.bold: true
                            Layout.fillWidth: true
                        }

                        Text {
                            text: root.currentMode === "wallpaper" ? "active" : ""
                            color: Theme.green
                            font.family: Theme.fontFamily
                            font.pixelSize: 8
                        }
                    }

                    MouseArea {
                        id: autoMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.wallpaperPath)
                                root.applyWallpaper(root.wallpaperPath);
                        }
                    }
                }

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    property bool isActive: root.currentMode === "preset" && root.modeName === modelData.name

                    width: presetList.width
                    height: 28
                    color: ma.containsMouse ? Theme.primary : (isActive ? Qt.alpha(Theme.primary, 0.15) : "transparent")
                    border.width: 1
                    border.color: isActive ? Theme.primary : Qt.alpha(Theme.primary, 0.3)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        Text {
                            text: modelData.variant === "light" ? "󰖨" : "󰖔"
                            color: isActive || ma.containsMouse ? (ma.containsMouse ? Theme.bg : Theme.primary) : Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }

                        Text {
                            text: modelData.name
                            color: isActive || ma.containsMouse ? (ma.containsMouse ? Theme.bg : Theme.primary) : Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.bold: true
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        Row {
                            spacing: 3
                            anchors.verticalCenter: parent.verticalCenter
                            Layout.alignment: Qt.AlignVCenter

                            Repeater {
                                model: [
                                    modelData.shell ? modelData.shell.bg : "",
                                    modelData.shell ? modelData.shell.surface : "",
                                    modelData.shell ? modelData.shell.fg : "",
                                    modelData.shell ? modelData.shell.primary : "",
                                    modelData.shell ? modelData.shell.blue : "",
                                    modelData.shell ? modelData.shell.error : ""
                                ]
                                delegate: Rectangle {
                                    width: 7; height: 7; color: modelData || "transparent"
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.applyPreset(modelData.name)
                    }
                }
            }
        }
    }
}
