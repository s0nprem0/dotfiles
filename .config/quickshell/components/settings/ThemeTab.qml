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
            "realpath \"" + path.replace(/"/g, '\\"') + "\" > " + absPath + " && " +
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

    function pickWallpaper() {
        Quickshell.execDetached(["sh", "-c",
            "[ -f " + Theme.home + "/.cache/quickshell/picker_running ] && exit 0; " +
            "touch " + Theme.home + "/.cache/quickshell/picker_running; " +
            "selected=$(zenity --file-selection " +
            "--file-filter='*.png' " +
            "--file-filter='*.jpg' " +
            "--file-filter='*.jpeg' " +
            "--file-filter='*.gif' " +
            "--file-filter='*.bmp' " +
            "--file-filter='*.webp' " +
            "--title='Choose Wallpaper' " +
            "--filename=" + Theme.home + "/Pictures/ " +
            " 2>/dev/null) && " +
            "if [ -n \"$selected\" ]; then " +
            "realpath \"$selected\" > " + Theme.home + "/.cache/quickshell/current_wallpaper && " +
            Theme.home + "/.config/hypr/scripts/wallpaper.sh \"$selected\"; " +
            "fi; " +
            "rm -f " + Theme.home + "/.cache/quickshell/picker_running"]);
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
                } catch (e) { console.warn("ThemeTab: preset list parse error", e); }
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
        anchors.margins: 16
        spacing: 16

        // ── Current Wallpaper ──
        Text {
            text: "CURRENT WALLPAPER"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLg
            color: Theme.primary
            font.bold: true
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 160
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
                                 height: 32
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.85) }
                }

RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    Text {
                        text: root.currentMode === "preset" ? "Preset: " + root.modeName : "Wallpaper"
                        color: Theme.primary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMd
                        font.bold: true
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Row {
                        spacing: 4

                        Repeater {
                            model: [Theme.bg, Theme.surface, Theme.surfaceLighter, Theme.primary, Theme.fg, Theme.muted]
                            delegate: Rectangle {
                                width: 10; height: 10; color: modelData
                            }
                        }
                    }
                }
            }
        }

        // ── Browse Button ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            color: browseMa.containsMouse ? Theme.primary : Theme.surface
            border.width: 1
            border.color: Theme.primary

            Text {
                anchors.centerIn: parent
                text: "󰉋  Browse Wallpaper"
                color: browseMa.containsMouse ? Theme.bg : Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMd
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
            color: Theme.primaryAlpha02
        }

        // ── Presets ──
        Text {
            text: "PRESETS"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLg
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
                spacing: 8

                header: Rectangle {
                    width: presetList.width
                    height: 32
                    color: autoMa.containsMouse ? Theme.primary : (root.currentMode === "wallpaper" ? Theme.primaryAlpha015 : "transparent")
                    border.width: 1
                    border.color: root.currentMode === "wallpaper" ? Theme.primary : Theme.primaryAlpha03

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰸉"
                            color: root.currentMode === "wallpaper" || autoMa.containsMouse ? (autoMa.containsMouse ? Theme.bg : Theme.primary) : Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXl
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Auto (wallpaper-based)"
                            color: root.currentMode === "wallpaper" || autoMa.containsMouse ? (autoMa.containsMouse ? Theme.bg : Theme.primary) : Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeMd
                            font.bold: true
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.currentMode === "wallpaper" ? "active" : ""
                            color: Theme.green
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
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
                                    height: 48
                                    color: ma.containsMouse ? Theme.primary : (isActive ? Theme.primaryAlpha015 : "transparent")
                                    border.width: 1
                                    border.color: isActive ? Theme.primary : Theme.primaryAlpha03

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        spacing: 10

                                        Text {
                                            text: modelData.variant === "light" ? "󰖨" : "󰖔"
                                            color: isActive || ma.containsMouse ? (ma.containsMouse ? Theme.bg : Theme.primary) : Theme.muted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeXl
                                        }

                                        Text {
                                            text: modelData.name
                                            color: isActive || ma.containsMouse ? (ma.containsMouse ? Theme.bg : Theme.primary) : Theme.fg
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeMd
                                            font.bold: true
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }

                                        Row {
                                            spacing: 3
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
                                                    width: 8; height: 8; color: modelData || "transparent"
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
