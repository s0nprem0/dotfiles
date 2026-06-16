import "../components/settings"
import "../service"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

PopupPanel {
    // ══════════════════════════════════════════════════════════════════════

    id: root

    property string hostname: ""
    property string kernel: ""
    property string uptime: ""
    property string os: ""
    property string batteryPercent: "--"
    property bool charging: false
    property string pendingAction: ""
    property string pendingLabel: ""
    property bool confirmVisible: false
    property string activeProfile: "balanced"
    property var availableProfiles: ["balanced", "power-saver", "performance"]
    // ── Data ─────────────────────────────────────────────────────────────
    property var sysActions: [{
        "icon": "󰌾",
        "label": "Lock",
        "cmd": ["hyprlock"],
        "confirm": false
    }, {
        "icon": "󰍃",
        "label": "Logout",
        "cmd": ["hyprctl", "dispatch", "exit"],
        "confirm": true
    }, {
        "icon": "󰤄",
        "label": "Sleep",
        "cmd": ["systemctl", "suspend"],
        "confirm": true
    }, {
        "icon": "󰜉",
        "label": "Reboot",
        "cmd": ["systemctl", "reboot"],
        "confirm": true
    }, {
        "icon": "󰐥",
        "label": "Shutdown",
        "cmd": ["systemctl", "poweroff"],
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

    function confirmAction(action, label) {
        pendingAction = action;
        pendingLabel = label;
        confirmVisible = true;
    }

    function closeWin() {
        root.closePopup();
        confirmVisible = false;
    }

    anchorSide: "none"
    panelWidth: 340
    panelMaxHeight: 600
    contentMargin: 16
    onBeforeOpen: refresh()

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

        command: ["sh", "-c", "for p in /sys/class/power_supply/BAT*/capacity; do [ -f \"$p\" ] && { cat \"$p\" && cat \"${p%capacity}status\"; break; }; done 2>/dev/null || printf '%s\n' '--' 'Unknown'"]

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
                root.closePopup();

        }
    }

    contentComponent: Component {
        ColumnLayout {
            id: mainColumn

            anchors.fill: parent
            spacing: 14

            // ── Header ─────────────────────────────────────────────────
            HeaderCard {
                hostname: root.hostname
                os: root.os
                uptime: root.uptime
                batteryPercent: root.batteryPercent
                charging: root.charging
            }

            // ── Section: System ────────────────────────────────────────
            Text {
                text: "System"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.bold: true
                opacity: 0.6
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: root.sysActions

                    delegate: Rectangle {
                        required property var modelData
                        property bool destructive: modelData.label === "Reboot" || modelData.label === "Shutdown"

                        implicitWidth: 48
                        implicitHeight: 52
                        radius: 8
                        color: mouseArea.containsMouse ? Theme.surfaceLighter : Theme.surface
                        border.width: 1
                        border.color: Theme.surfaceLighter

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2

                            Text {
                                text: modelData.icon
                                color: parent.parent.destructive ? Theme.error : Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: 16
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: modelData.label
                                color: parent.parent.destructive ? Theme.error : Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                Layout.alignment: Qt.AlignHCenter
                            }

                        }

                        MouseArea {
                            id: mouseArea

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                if (modelData.confirm)
                                    root.confirmAction(modelData.cmd.join(" "), modelData.label);
                                else
                                    Quickshell.execDetached(modelData.cmd);
                            }
                        }

                    }

                }

            }

            // ── Confirm dialog ─────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                visible: root.confirmVisible
                height: 36
                radius: 6
                color: Theme.surface

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8

                    Text {
                        text: "Confirm " + root.pendingLabel + "?"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "Cancel"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 10

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.confirmVisible = false
                        }

                    }

                    Rectangle {
                        width: 48
                        height: 22
                        radius: 4
                        color: Theme.error

                        Text {
                            anchors.centerIn: parent
                            text: "Yes"
                            color: Theme.bg
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                actionProc.command = ["sh", "-c", root.pendingAction];
                                actionProc.running = true;
                            }
                        }

                    }

                }

            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.primary
                opacity: 0.15
            }

            // ── Section: Network ────────────────────────────────────────
            Text {
                text: "Network"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.bold: true
                opacity: 0.6
            }

            Rectangle {
                property alias ma: ma

                Layout.fillWidth: true
                height: 36
                radius: 6
                color: ma.containsMouse ? Theme.surfaceLighter : Theme.surface
                border.width: 1
                border.color: Theme.surfaceLighter

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8

                    Text {
                        text: "󰤨"
                        color: Theme.primary
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                    }

                    Text {
                        text: "WiFi Manager (impala)"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "Launch"
                        color: Theme.primary
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.bold: true
                    }

                }

                MouseArea {
                    id: ma

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        Quickshell.execDetached(Config.impalaCmd);
                        root.closeWin();
                    }
                }

            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.primary
                opacity: 0.15
            }

            // ── Section: Power Profile ─────────────────────────────────
            Text {
                text: "Power Profile"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.bold: true
                opacity: 0.6
            }

            PowerCard {
                activeProfile: root.activeProfile
                onProfileSelected: function(profile) {
                    root.setProfile(profile);
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.primary
                opacity: 0.15
            }

            // ── Section: About ─────────────────────────────────────────
            Text {
                text: "About"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.bold: true
                opacity: 0.6
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: root.aboutRows

                    delegate: RowLayout {
                        required property var modelData

                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: modelData.label
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                        }

                        Text {
                            text: modelData.value
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                    }

                }

            }

        }

    }

}
