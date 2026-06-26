import "../components/settings"
import "../service"
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io

Window {
    id: root

    property bool showPopup: false
    // ── Data ──
    property string hostname: ""
    property string kernel: ""
    property string uptime: ""
    property string os: ""
    property string batteryPercent: "--"
    property bool charging: false
    property var pendingAction: ""
    property string pendingLabel: ""
    property bool confirmVisible: false
    property string activeProfile: "balanced"
    property var availableProfiles: ["balanced", "power-saver", "performance"]
    property int chargeLimit: 80
    property int currentBrightness: 80
    property int currentKbd: 50
    property int currentTab: 0
    readonly property var tabData: [{
        "icon": "󰒓",
        "label": "System"
    }, {
        "icon": "󰢟",
        "label": "Power"
    }, {
        "icon": "󰤨",
        "label": "Network"
    }, {
        "icon": "󰸌",
        "label": "Theme"
    }, {
        "icon": "󰻞",
        "label": "About"
    }]
    property var sysActions: [{
        "icon": "󰌾",
        "label": "Lock",
        "cmd": [Theme.bin("powerctl.sh"), "lock"],
        "confirm": false
    }, {
        "icon": "󰍃",
        "label": "Logout",
        "cmd": [Theme.bin("powerctl.sh"), "logout"],
        "confirm": true
    }, {
        "icon": "󰤄",
        "label": "Sleep",
        "cmd": [Theme.bin("powerctl.sh"), "sleep"],
        "confirm": true
    }, {
        "icon": "󰜉",
        "label": "Reboot",
        "cmd": [Theme.bin("powerctl.sh"), "reboot"],
        "confirm": true
    }, {
        "icon": "󰐥",
        "label": "Shutdown",
        "cmd": [Theme.bin("powerctl.sh"), "poweroff"],
        "confirm": true
    }]
    property var aboutRows: [{
        "label": "Host",
        "value": root.hostname
    }, {
        "label": "OS",
        "value": root.os
    }, {
        "label": "Kernel",
        "value": root.kernel
    }, {
        "label": "Uptime",
        "value": root.uptime
    }]

    function refresh() {
        sysInfoProc.running = true;
        uptimeProc.running = true;
        batteryProc.running = true;
        profileProc.running = true;
    }

    function setProfile(profile) {
        root.activeProfile = profile;
        setProfileProc.command = [Theme.bin("set_power_profile.sh"), profile];
        setProfileProc.running = true;
    }

    function setBrightness(pct) {
        root.currentBrightness = pct;
        brightProc.command = ["brightnessctl", "set", pct + "%"];
        brightProc.running = true;
    }

    function setKbdBrightness(pct) {
        root.currentKbd = pct;
        kbdProc.command = [
            "sh", "-c",
            "dev=$(ls /sys/class/leds/*kbd_backlight 2>/dev/null | head -1) && " +
            "[ -n \"$dev\" ] && brightnessctl -d \"$(basename \"$dev\")\" set " + pct + "%"
        ];
        kbdProc.running = true;
    }

    function confirmAction(action, label) {
        pendingAction = action;
        pendingLabel = label;
        confirmVisible = true;
    }

    function closeWin() {
        root.showPopup = false;
        confirmVisible = false;
    }

    title: "Quickshell Settings"
    minimumWidth: 640
    minimumHeight: 520
    width: 720
    height: 560
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint
    visible: showPopup
    onVisibleChanged: {
        if (visible)
            refresh();

    }
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            root.closeWin();
            event.accepted = true;
        }
    }

    // ── Processes ──
    Process {
        id: sysInfoProc

        command: [Theme.bin("get_sysinfo.sh")]

        stdout: StdioCollector {
            onStreamFinished: {
                var lines = (this.text || "").trim().split("\n");
                if (lines.length >= 3) {
                    root.hostname = lines[0].trim();
                    root.kernel = lines[1].trim();
                    root.os = lines.slice(2).join("\n").trim();
                }
            }
        }

    }

    Process {
        id: uptimeProc

        command: ["uptime", "-p"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.uptime = (this.text || "").trim().replace(/^up /i, "");
            }
        }

    }

    Process {
        id: batteryProc

        command: ["sh", "-c", "for p in /sys/class/power_supply/BAT*/capacity; do [ -f \"$p\" ] && { cat \"$p\" && cat \"${p%capacity}status\"; break; }; done 2>/dev/null || printf '%s\\n' '--' 'Unknown'"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = (this.text || "").trim().split("\n");
                if (lines.length >= 2) {
                    root.batteryPercent = lines[0];
                    root.charging = lines[1] === "Charging";
                }
            }
        }

    }

    Process {
        id: profileProc

        command: [Theme.bin("get_power_profile")]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(this.text.trim());
                    root.activeProfile = j.active ?? "balanced";
                    root.availableProfiles = j.available ?? [root.activeProfile];
                } catch (e) {
                }
            }
        }

    }

    Process {
        id: setProfileProc

        onExited: profileProc.running = true
    }

    Process {
        id: actionProc

        onExited: {
            if (root.showPopup)
                root.closeWin();

        }
    }

    Process {
        id: brightProc
    }

    Process {
        id: kbdProc
    }

    // ── UI ──
    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        border.width: 2
        border.color: Theme.primary

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ── Title bar (solid block) ──
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                color: Theme.primary

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8
                    spacing: 10

                    Text {
                        text: "󰒓"
                        color: Theme.bg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize4xl
                    }

                    Text {
                        text: "SYSTEM SETTINGS"
                        color: Theme.bg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize3xl
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        implicitWidth: 32
                        implicitHeight: 32
                        color: closeMa.containsMouse ? Theme.bg : "transparent"
                        border.width: 1
                        border.color: closeMa.containsMouse ? Theme.bg : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: closeMa.containsMouse ? Theme.primary : Theme.bg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXl
                            font.bold: true
                        }

                        MouseArea {
                            id: closeMa

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closeWin()
                        }

                    }

                }

            }

            // ── Body ──
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                // ── Sidebar ──
                Rectangle {
                    Layout.preferredWidth: 160
                    Layout.fillHeight: true
                    color: Theme.surface

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 4

                        Repeater {
                            model: root.tabData

                            delegate: Rectangle {
                                required property var modelData
                                required property int index

                                Layout.fillWidth: true
                                Layout.preferredHeight: 52
                                color: index === root.currentTab ? Theme.primary : (tabMa.containsMouse ? Theme.surfaceLighter : "transparent")
                                border.width: index === root.currentTab ? 1 : 0
                                border.color: Theme.primary

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 10
                                    spacing: 12

                                    Text {
                                        text: modelData.icon
                                        color: index === root.currentTab ? Theme.bg : Theme.primary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize4xl
                                    }

                                    Text {
                                        text: modelData.label
                                        color: index === root.currentTab ? Theme.bg : Theme.fg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeLg
                                        font.bold: true
                                        Layout.fillWidth: true
                                    }

                                }

                                MouseArea {
                                    id: tabMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.currentTab = index
                                }

                            }

                        }

                        Item {
                            Layout.fillHeight: true
                        }

                    }

                }

                // ── Separator ──
                Rectangle {
                    Layout.preferredWidth: 2
                    Layout.fillHeight: true
                    color: Theme.primary
                }

                // ── Content ──
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Theme.surface

                    StackLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        currentIndex: root.currentTab

                        SystemTab {
                            hostname: root.hostname
                            os: root.os
                            uptime: root.uptime
                            batteryPercent: root.batteryPercent
                            charging: root.charging
                            sysActions: root.sysActions
                            confirmVisible: root.confirmVisible
                            pendingAction: root.pendingAction
                            pendingLabel: root.pendingLabel
                            onConfirmAction: (a, l) => {
                                return root.confirmAction(a, l);
                            }
                            onCloseConfirm: root.confirmVisible = false
                            onExecuteAction: (cmd) => {
                                actionProc.command = cmd;
                                actionProc.running = true;
                            }
                        }

                        PowerTab {
                            activeProfile: root.activeProfile
                            availableProfiles: root.availableProfiles
                            chargeLimit: root.chargeLimit
                            currentBrightness: root.currentBrightness
                            currentKbd: root.currentKbd
                            onSetProfile: (p) => {
                                return root.setProfile(p);
                            }
                            onBrightnessChanged: (pct) => {
                                root.setBrightness(pct);
                            }
                            onKbdChanged: (pct) => {
                                root.setKbdBrightness(pct);
                            }
                        }

                        NetworkTab {
                            onOpenImpala: {
                                Quickshell.execDetached(Config.impalaCmd);
                                root.closeWin();
                            }
                        }

                        ThemeTab {
                            onCloseSettings: root.closeWin()
                        }

                        AboutTab {
                            aboutRows: root.aboutRows
                        }

                    }

                }

            }

        }

    }

}
