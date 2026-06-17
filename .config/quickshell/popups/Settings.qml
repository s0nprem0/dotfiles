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

    // Responsive Base Dimensions
    minimumWidth: 480
    minimumHeight: 400
    width: 520
    height: 440
    color: "transparent"

    flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowTransparentForInput

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
    Process { id: uptimeProc; command: ["uptime", "-p"]; stdout: StdioCollector { onStreamFinished: { root.uptime = (this.text || "").trim().replace(/^up /i, ""); } } }
    Process {
        id: batteryProc
        command: ["sh", "-c", "for p in /sys/class/power_supply/BAT*/capacity; do [ -f \"$p\" ] && { cat \"$p\" && cat \"${p%capacity}status\"; break; }; done 2>/dev/null || printf '%s\\n' '--' 'Unknown'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = (this.text || "").trim().split("\n");
                if (lines.length >= 2) { root.batteryPercent = lines[0]; root.charging = lines[1] === "Charging"; }
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

    // ── UI Blocky Layout ──
    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        border.width: 2 // Strong outer frame
        border.color: Theme.primary
        radius: 0 // Sharp corners

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ── Blocky Title bar ──
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

                    // Sharp Close Button
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

            // ── Body ──
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                // ── Blocky Sidebar ──
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
                                radius: 0 // Blocky tabs

                                // Hard color inversion on selection/hover
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
                        Item { Layout.fillHeight: true } // Push tabs to top
                    }
                }

                // ── Content area (Native Flickable for safety) ──
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Theme.bg

                    StackLayout {
                        anchors.fill: parent
                        currentIndex: root.currentTab

                        // ── Tab 0: System ──
                        Flickable {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            contentHeight: sysCol.implicitHeight + 32; clip: true; boundsBehavior: Flickable.StopAtBounds

                            ColumnLayout {
                                id: sysCol
                                width: parent.width - 32; x: 16; y: 16; spacing: 16

                                HeaderCard {
                                    Layout.fillWidth: true
                                    hostname: root.hostname; os: root.os; uptime: root.uptime
                                    batteryPercent: root.batteryPercent; charging: root.charging
                                }

                                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.primary } // Hard divider

                                Text { text: "QUICK ACTIONS"; color: Theme.primary; font.family: Theme.fontFamily; font.pixelSize: 10; font.bold: true }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Repeater {
                                        model: root.sysActions
                                        delegate: Rectangle {
                                            required property var modelData
                                            property bool destructive: modelData.label === "Reboot" || modelData.label === "Shutdown"
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 56
                                            radius: 0 // Block buttons

                                            color: ma.containsMouse ? (destructive ? Theme.error : Theme.primary) : "transparent"
                                            border.width: 1
                                            border.color: destructive ? Theme.error : Theme.primary

                                            ColumnLayout {
                                                anchors.centerIn: parent
                                                spacing: 6
                                                Text { text: modelData.icon; color: ma.containsMouse ? Theme.bg : (parent.parent.destructive ? Theme.error : Theme.primary); font.family: Theme.fontFamily; font.pixelSize: 16; Layout.alignment: Qt.AlignHCenter }
                                                Text { text: modelData.label; color: ma.containsMouse ? Theme.bg : Theme.fg; font.family: Theme.fontFamily; font.pixelSize: 9; font.bold: true; Layout.alignment: Qt.AlignHCenter }
                                            }

                                            MouseArea {
                                                id: ma
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                hoverEnabled: true
                                                onClicked: {
                                                    if (modelData.confirm) root.confirmAction(modelData.cmd.join(" "), modelData.label);
                                                    else Quickshell.execDetached(modelData.cmd);
                                                }
                                            }
                                        }
                                    }
                                }

                                // ── Blocky Confirm dialog ──
                                Rectangle {
                                    Layout.fillWidth: true
                                    visible: root.confirmVisible
                                    height: 44
                                    radius: 0
                                    color: Theme.bg
                                    border.width: 1; border.color: Theme.error

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 12
                                        Text { text: "EXECUTE " + root.pendingLabel.toUpperCase() + "?"; color: Theme.error; font.family: Theme.fontFamily; font.pixelSize: 10; font.bold: true; Layout.fillWidth: true }

                                        Rectangle {
                                            width: 70; height: 28; radius: 0; color: "transparent"; border.width: 1; border.color: Theme.fg
                                            Text { anchors.centerIn: parent; text: "CANCEL"; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: 9; font.bold: true }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.confirmVisible = false }
                                        }

                                        Rectangle {
                                            width: 70; height: 28; radius: 0; color: Theme.error
                                            Text { anchors.centerIn: parent; text: "CONFIRM"; color: Theme.bg; font.family: Theme.fontFamily; font.pixelSize: 9; font.bold: true }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: { actionProc.command = ["sh", "-c", root.pendingAction]; actionProc.running = true; }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ── Tab 1: Power ──
                        Flickable {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            contentHeight: pwrCol.implicitHeight + 32; clip: true; boundsBehavior: Flickable.StopAtBounds
                            ColumnLayout {
                                id: pwrCol; width: parent.width - 32; x: 16; y: 16; spacing: 16
                                Text { text: "POWER MANAGEMENT"; color: Theme.primary; font.family: Theme.fontFamily; font.pixelSize: 10; font.bold: true }
                                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.primary }
                                PowerCard {
                                    Layout.fillWidth: true
                                    activeProfile: root.activeProfile
                                    onProfileSelected: function(profile) { root.setProfile(profile); }
                                }
                            }
                        }

                        // ── Tab 2: Network ──
                        Flickable {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            contentHeight: netCol.implicitHeight + 32; clip: true; boundsBehavior: Flickable.StopAtBounds
                            ColumnLayout {
                                id: netCol; width: parent.width - 32; x: 16; y: 16; spacing: 16
                                Text { text: "NETWORK TOOLS"; color: Theme.primary; font.family: Theme.fontFamily; font.pixelSize: 10; font.bold: true }
                                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.primary }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 60
                                    radius: 0
                                    color: nwMa.containsMouse ? Theme.primary : "transparent"
                                    border.width: 1
                                    border.color: Theme.primary

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 14
                                        Text { text: "󰤨"; color: nwMa.containsMouse ? Theme.bg : Theme.primary; font.family: Theme.fontFamily; font.pixelSize: 22 }
                                        ColumnLayout {
                                            spacing: 4; Layout.fillWidth: true
                                            Text { text: "ADVANCED WIFI MANAGER"; color: nwMa.containsMouse ? Theme.bg : Theme.fg; font.family: Theme.fontFamily; font.pixelSize: 10; font.bold: true }
                                            Text { text: "Launch Impala TUI network utility"; color: nwMa.containsMouse ? Theme.bg : Theme.muted; font.family: Theme.fontFamily; font.pixelSize: 9 }
                                        }
                                        Text { text: "LAUNCH"; color: nwMa.containsMouse ? Theme.bg : Theme.primary; font.family: Theme.fontFamily; font.pixelSize: 10; font.bold: true }
                                    }
                                    MouseArea {
                                        id: nwMa
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onClicked: { Quickshell.execDetached(Config.impalaCmd); root.closeWin(); }
                                    }
                                }
                            }
                        }

                        // ── Tab 3: About ──
                        Flickable {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            contentHeight: abtCol.implicitHeight + 32; clip: true; boundsBehavior: Flickable.StopAtBounds
                            ColumnLayout {
                                id: abtCol; width: parent.width - 32; x: 16; y: 16; spacing: 16
                                Text { text: "SYSTEM INFORMATION"; color: Theme.primary; font.family: Theme.fontFamily; font.pixelSize: 10; font.bold: true }
                                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.primary }

                                Rectangle {
                                    Layout.fillWidth: true
                                    radius: 0; color: "transparent"; border.width: 1; border.color: Theme.primary
                                    ColumnLayout {
                                        anchors.fill: parent; anchors.margins: 16; spacing: 12
                                        Repeater {
                                            model: root.aboutRows
                                            delegate: RowLayout {
                                                required property var modelData
                                                Layout.fillWidth: true; spacing: 12
                                                Text { text: modelData.label.toUpperCase(); color: Theme.primary; font.family: Theme.fontFamily; font.pixelSize: 10; font.bold: true; Layout.preferredWidth: 60 }
                                                Text { text: modelData.value; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
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
    }
}
