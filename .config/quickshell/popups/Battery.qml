import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../service"
import "../components/settings"

PopupPanel {
    id: root

    anchorSide: "none"
    panelWidth: 340
    panelMaxHeight: 0
    contentMargin: 12

    // ── Battery data ──
    property int capacity: 0
    property string status: "Unknown"
    property real health: 100
    property real powerDraw: 0
    property string timeRemaining: ""
    property var sparkline: []
    property string activeProfile: "balanced"
    property var availableProfiles: []

    // ── Automation settings ──
    property bool automationEnabled: true
    property int lowThreshold: 25
    property string acProfile: "performance"
    property string batProfile: "balanced"
    property string lowProfile: "power-saver"
    property int acBrightness: 100
    property int batBrightness: 70
    property int lowBrightness: 30
    property int acKbd: 100
    property int batKbd: 33
    property int lowKbd: 0

    // ── Derived ──
    readonly property bool isCharging: root.status === "Charging" || root.status === "Full"

    readonly property string statusIcon: {
        if (root.isCharging) return ""
        if (root.capacity >= 90) return ""
        if (root.capacity >= 60) return ""
        if (root.capacity >= 40) return ""
        if (root.capacity >= 20) return ""
        return ""
    }

    readonly property string modeLabel: {
        if (root.isCharging) return "AC Mode"
        if (root.capacity <= root.lowThreshold) return "Low Battery"
        return "Battery Mode"
    }

    readonly property string modeProfile: {
        if (root.isCharging) return root.acProfile
        if (root.capacity <= root.lowThreshold) return root.lowProfile
        return root.batProfile
    }

    readonly property int modeBrightness: {
        if (root.isCharging) return root.acBrightness
        if (root.capacity <= root.lowThreshold) return root.lowBrightness
        return root.batBrightness
    }

    // ── Settings file path ──
    readonly property string settingsFile: Quickshell.env("HOME") + "/.cache/quickshell/battery_settings.json"
    readonly property string settingsDir: Quickshell.env("HOME") + "/.cache/quickshell"

    // ── Refresh ──
    onBeforeOpen: refresh()

    function refresh() {
        statusProc.running = true
        profileProc.running = true
        loadSettings()
    }

    // ── Settings persistence ──
    function applySettings(raw) {
        if (!raw) return
        try {
            var j = JSON.parse(raw)
            if (!j) return
            root.automationEnabled = j.automation_enabled !== undefined ? j.automation_enabled : true
            root.lowThreshold = j.low_battery_threshold ?? 25
            root.acProfile = j.ac_profile ?? "performance"
            root.batProfile = j.bat_profile ?? "balanced"
            root.lowProfile = j.low_profile ?? "power-saver"
            root.acBrightness = j.ac_screen_brightness ?? 100
            root.batBrightness = j.bat_screen_brightness ?? 70
            root.lowBrightness = j.low_screen_brightness ?? 30
            root.acKbd = j.ac_kbd_brightness ?? 100
            root.batKbd = j.bat_kbd_brightness ?? 33
            root.lowKbd = j.low_kbd_brightness ?? 0
        } catch (e) {}
    }

    function loadSettings() {
        readFileCmd.running = true
    }

    Process {
        id: readFileCmd
        command: ["sh", "-c", "cat \"" + root.settingsFile + "\" 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: root.applySettings(this.text.trim())
        }
    }

    function saveSettings() {
        var j = JSON.stringify({
            automation_enabled: root.automationEnabled,
            low_battery_threshold: root.lowThreshold,
            ac_profile: root.acProfile,
            bat_profile: root.batProfile,
            low_profile: root.lowProfile,
            ac_screen_brightness: root.acBrightness,
            bat_screen_brightness: root.batBrightness,
            low_screen_brightness: root.lowBrightness,
            ac_kbd_brightness: root.acKbd,
            bat_kbd_brightness: root.batKbd,
            low_kbd_brightness: root.lowKbd,
        })
        writeFileCmd.command = ["sh", "-c",
            "mkdir -p \"$2\" && printf '%s' \"$1\" > \"$2/battery_settings.json\"",
            "_", j, root.settingsDir]
        writeFileCmd.running = true
    }

    Process { id: writeFileCmd }

    Component.onCompleted: loadSettings()

    // ── Set profile ──
    function setProfile(profile) {
        root.activeProfile = profile
        setProc.command = [
            "busctl", "set-property",
            "net.hadess.PowerProfiles",
            "/net/hadess/PowerProfiles",
            "net.hadess.PowerProfiles",
            "ActiveProfile", "s", profile,
        ]
        setProc.running = true
    }

    // ── Set brightness ──
    function setBrightness(pct) {
        brightProc.command = ["brightnessctl", "set", pct + "%"]
        brightProc.running = true
    }

    // ── Battery status Process ──
    Process {
        id: statusProc
        command: [Theme.bin("get_battery_status")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(this.text.trim())
                    root.capacity = j.capacity ?? 0
                    root.status = j.status ?? "Unknown"
                    root.health = j.health ?? 100
                    root.powerDraw = j.power_draw_w ?? 0
                    root.timeRemaining = j.time_remaining ?? "N/A"
                    root.sparkline = j.sparkline ?? []
                } catch (e) { console.warn("Battery: parse error", e) }
            }
        }
    }

    // ── Power profile Process ──
    Process {
        id: profileProc
        command: [Theme.bin("get_power_profile")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(this.text.trim())
                    root.activeProfile = j.active ?? "balanced"
                    root.availableProfiles = j.available ?? []
                } catch (e) {}
            }
        }
    }

    // ── Set profile Process ──
    Process { id: setProc }

    // ── Set brightness Process ──
    Process { id: brightProc }

    // ── Action Process ──
    Process { id: actionProc }

    // ── Refresh timer ──
    Timer {
        id: refreshTimer
        interval: 5000
        running: root.showPopup
        repeat: true
        onTriggered: refresh()
    }

    // ══════════════════════════════════════════════════════════════════════

    contentComponent: Component {
        ColumnLayout {
            id: mainColumn
            anchors.fill: parent
            spacing: 12

            // ═══════════════════════════════════════════════════════════
            // HEADER
            // ═══════════════════════════════════════════════════════════
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: root.statusIcon
                    color: root.isCharging ? Theme.green : Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 36
                }

                ColumnLayout {
                    spacing: 2
                    Layout.fillWidth: true

                    RowLayout {
                        spacing: 6

                        Text {
                            text: root.capacity + "%"
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 24
                            font.bold: true
                        }

                        Text {
                            text: "\u00b7  " + root.powerDraw.toFixed(1) + "W"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            Layout.alignment: Qt.AlignBottom
                            anchors.bottomMargin: 4
                        }
                    }

                    Text {
                        text: {
                            if (root.isCharging && root.capacity >= 100) return "Fully charged"
                            if (root.isCharging) return "Charging \u00b7 " + root.timeRemaining + " until full"
                            return "Discharging \u00b7 " + root.timeRemaining + " remaining"
                        }
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }
                }
            }

            // ═══════════════════════════════════════════════════════════
            // STATS
            // ═══════════════════════════════════════════════════════════
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    height: 44
                    radius: 6
                    color: Theme.surface

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 1

                        Text {
                            text: root.health.toFixed(0) + "%"
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.bold: true
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            text: "Health"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 8
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 44
                    radius: 6
                    color: Theme.surface

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 1

                        Text {
                            text: root.timeRemaining
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.bold: true
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            text: root.isCharging ? "Until Full" : "Remaining"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 8
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }

            // ── Sparkline ──
            Rectangle {
                Layout.fillWidth: true
                height: 28
                radius: 4
                color: Theme.surface
                visible: root.sparkline.length > 0

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 2
                    layoutDirection: Qt.RightToLeft

                    Repeater {
                        model: root.sparkline

                        delegate: Rectangle {
                            required property var modelData

                            Layout.fillHeight: true
                            Layout.preferredWidth: 4

                            color: {
                                var v = modelData
                                if (v > 20) return Theme.error
                                if (v > 10) return Theme.warning
                                return Theme.green
                            }
                            radius: 1

                            Layout.maximumHeight: {
                                var maxVal = Math.max.apply(null, root.sparkline)
                                return maxVal > 0 ? (modelData / maxVal) * parent.height : 2
                            }
                            Layout.alignment: Qt.AlignBottom
                        }
                    }
                }
            }

            // ═══════════════════════════════════════════════════════════
            // AUTOMATIONS
            // ═══════════════════════════════════════════════════════════
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "\u26a1 Battery Automations"
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                    Layout.fillWidth: true
                }

                Rectangle {
                    width: 36
                    height: 18
                    radius: 9
                    color: root.automationEnabled ? Theme.green : Theme.surfaceLighter

                    Rectangle {
                        x: root.automationEnabled ? 18 : 2
                        y: 2
                        width: 14
                        height: 14
                        radius: 7
                        color: Theme.bg

                        Behavior on x { NumberAnimation { duration: 120 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.automationEnabled = !root.automationEnabled
                            root.saveSettings()
                        }
                    }
                }
            }

            // ── AC Mode card ──
            ModeCard {
                cardTitle: "AC Mode"
                active: root.isCharging
                currentProfile: root.acProfile
                currentBrightness: root.acBrightness
                onProfileChanged: function(p) { root.acProfile = p; root.saveSettings() }
                onBrightnessChanged: function(p) { root.acBrightness = p; root.saveSettings(); root.setBrightness(p) }
            }

            // ── Battery Mode card ──
            ModeCard {
                cardTitle: "Battery Mode"
                active: !root.isCharging && root.capacity > root.lowThreshold
                currentProfile: root.batProfile
                currentBrightness: root.batBrightness
                onProfileChanged: function(p) { root.batProfile = p; root.saveSettings() }
                onBrightnessChanged: function(p) { root.batBrightness = p; root.saveSettings(); root.setBrightness(p) }
            }

            // ── Low Battery card ──
            ModeCard {
                cardTitle: "Low Battery"
                active: !root.isCharging && root.capacity <= root.lowThreshold
                currentProfile: root.lowProfile
                currentBrightness: root.lowBrightness
                onProfileChanged: function(p) { root.lowProfile = p; root.saveSettings() }
                onBrightnessChanged: function(p) { root.lowBrightness = p; root.saveSettings(); root.setBrightness(p) }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.primary
                opacity: 0.15
            }

            // ═══════════════════════════════════════════════════════════
            // POWER MODE OVERRIDE
            // ═══════════════════════════════════════════════════════════
            Text {
                text: "Power Mode Override"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.bold: true
                opacity: 0.6
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: [
                        {label: "Saver", val: "power-saver", icon: "\uf0ae"},
                        {label: "Balanced", val: "balanced", icon: "\uf0e7"},
                        {label: "Performance", val: "performance", icon: "\uf0e7"},
                    ]

                    delegate: Rectangle {
                        required property var modelData

                        Layout.fillWidth: true
                        height: 44
                        radius: 6
                        color: root.activeProfile === modelData.val ? Theme.primary : Theme.surface
                        border.width: 1
                        border.color: root.activeProfile === modelData.val ? Theme.primary : Theme.surfaceLighter

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2

                            Text {
                                text: modelData.val === "performance" ? "\uf0e7" : modelData.val === "power-saver" ? "\uf0ae" : "\uf2dc"
                                color: root.activeProfile === modelData.val ? Theme.bg : Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: modelData.label
                                color: root.activeProfile === modelData.val ? Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.7) : Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: root.setProfile(modelData.val)
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

            // ═══════════════════════════════════════════════════════════
            // POWER ACTIONS
            // ═══════════════════════════════════════════════════════════
            Text {
                text: "Power Actions"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.bold: true
                opacity: 0.6
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: [
                        {icon: "\uf186", label: "Sleep", cmd: "systemctl suspend"},
                        {icon: "\uf021", label: "Reboot", cmd: "systemctl reboot"},
                        {icon: "\uf011", label: "Shutdown", cmd: "systemctl poweroff"},
                    ]

                    delegate: Rectangle {
                        required property var modelData

                        Layout.fillWidth: true
                        height: 44
                        radius: 6
                        color: mouseArea.containsMouse ? Theme.surfaceLighter : Theme.surface
                        border.width: 1
                        border.color: Theme.surfaceLighter

                        property bool destructive: modelData.label === "Reboot" || modelData.label === "Shutdown"

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
                                actionProc.command = ["sh", "-c", modelData.cmd]
                                actionProc.running = true
                            }
                        }
                    }
                }
            }
        }
    }
}
