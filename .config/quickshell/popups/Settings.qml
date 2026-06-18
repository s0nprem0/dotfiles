import "../components/settings"
import "../service"
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io

Window {
    id: root

    title: "Quickshell Settings"

    minimumWidth: 480
    minimumHeight: 400
    width: 520
    height: 440
    color: "transparent"

    flags: Qt.Window | Qt.FramelessWindowHint

    property bool showPopup: false
    visible: showPopup

    onVisibleChanged: {
        if (visible) refresh();
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            root.closeWin();
            event.accepted = true;
        }
    }

    // ── Data properties ──
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
    property int currentTab: 0

    readonly property var tabData: [
        { icon: "󰒓", label: "System" },
        { icon: "󰢟", label: "Power" },
        { icon: "󰤨", label: "Network" },
        { icon: "󰻞", label: "About" },
    ]

    property var sysActions: [
        { icon: "󰌾", label: "Lock",     cmd: ["hyprlock"],                 confirm: false },
        { icon: "󰍃", label: "Logout",   cmd: ["hyprctl", "dispatch", "exit"], confirm: true  },
        { icon: "󰤄", label: "Sleep",    cmd: ["systemctl", "suspend"],        confirm: true  },
        { icon: "󰜉", label: "Reboot",   cmd: ["systemctl", "reboot"],         confirm: true  },
        { icon: "󰐥", label: "Shutdown", cmd: ["systemctl", "poweroff"],       confirm: true  },
    ]

    property var aboutRows: [
        { label: "Host",   value: root.hostname },
        { label: "OS",     value: root.os       },
        { label: "Kernel", value: root.kernel   },
        { label: "Uptime", value: root.uptime   },
    ]

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
        root.showPopup = false;
        confirmVisible = false;
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
        id: uptimeProc;
        command: ["uptime", "-p"];
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
                } catch (e) {}
            }
        }
    }

    Process { id: setProfileProc; onExited: profileProc.running = true }
    Process { id: actionProc; onExited: { if (root.showPopup) root.closeWin(); } }

    // ── UI Layout ──
    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        border.width: 2
        border.color: Theme.primary
        radius: 0

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Title bar
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

                    Text { text: "󰒓"; color: Theme.primary; font.family: Theme.fontFamily; font.pixelSize: 13 }
                    Text { text: "SYSTEM SETTINGS"; color: Theme.primary; font.family: Theme.fontFamily; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }

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
                            onClicked: root.closeWin()
                        }
                    }
                }
            }

            // Body
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                // Sidebar
                Rectangle {
                    Layout.preferredWidth: 120
                    Layout.fillHeight: true
                    color: Theme.bg
                    border.width: 1
                    border.color: Theme.primary

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        Repeater {
                            model: root.tabData
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                radius: 0

                                color: index === root.currentTab ? Theme.primary : (tabMa.containsMouse ? Theme.surfaceLighter : "transparent")
                                border.width: 1
                                border.color: index === root.currentTab ? Theme.primary : Theme.surfaceLighter

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    spacing: 10
                                    Text {
                                        text: modelData.icon;
                                        color: index === root.currentTab ? Theme.bg : Theme.fg;
                                        font.family: Theme.fontFamily; font.pixelSize: 13
                                    }
                                    Text {
                                        text: modelData.label;
                                        color: index === root.currentTab ? Theme.bg : Theme.fg;
                                        font.family: Theme.fontFamily; font.pixelSize: 10; font.bold: true
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
                        Item { Layout.fillHeight: true }
                    }
                }

                // Content Area
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Theme.bg

                    StackLayout {
                        anchors.fill: parent
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
                            onConfirmAction: (action, label) => root.confirmAction(action, label)
                            onCloseConfirm: root.confirmVisible = false
                            onExecuteAction: (cmd) => {
                                actionProc.command = cmd;
                                actionProc.running = true;
                            }
                        }

                        PowerTab {
                            activeProfile: root.activeProfile
                            availableProfiles: root.availableProfiles
                            onSetProfile: (profile) => root.setProfile(profile)
                        }

                        NetworkTab {
                            onOpenImpala: {
                                Quickshell.execDetached(Config.impalaCmd);
                                root.closeWin();
                            }
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
