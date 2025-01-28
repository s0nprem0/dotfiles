import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../service"

Item {
    id: root

    property bool showPopup: false

    property string hostname: ""
    property string kernel: ""
    property string uptime: ""
    property string os: ""

    property string pendingAction: ""
    property string pendingLabel: ""
    property bool confirmVisible: false

    onShowPopupChanged: { if (showPopup) refresh() }

    function refresh() {
        sysInfoProc.running = true
        uptimeProc.running = true
    }

    function confirmAction(action, label) {
        pendingAction = action
        pendingLabel = label
        confirmVisible = true
    }

    function closeWin() {
        showPopup = false
        confirmVisible = false
    }

    Process {
        id: sysInfoProc
        command: ["sh", "-c", "hostname; echo ---; uname -r; echo ---; . /etc/os-release 2>/dev/null && echo \"$NAME $VERSION_ID\" || echo \"Arch Linux\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = (this.text || "").trim().split("\n---\n")
                if (parts.length >= 3) {
                    root.hostname = parts[0].trim()
                    root.kernel = parts[1].trim()
                    root.os = parts[2].trim()
                }
            }
        }
    }

    Process {
        id: uptimeProc
        command: ["uptime", "-p"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.uptime = (this.text || "").trim().replace(/^up /i, "")
            }
        }
    }

    Process {
        id: actionProc
        onExited: { if (root.showPopup) root.showPopup = false }
    }

    // ── Data ─────────────────────────────────────────────────────────────
    property var sysActions: [
        { icon: "󰌾", label: "Lock",    cmd: ["hyprlock"],                     confirm: false },
        { icon: "󰍃", label: "Logout",  cmd: ["hyprctl", "dispatch", "exit"],  confirm: true  },
        { icon: "󰤄", label: "Sleep",   cmd: ["systemctl", "suspend"],         confirm: true  },
        { icon: "󰜉", label: "Reboot",  cmd: ["systemctl", "reboot"],          confirm: true  },
        { icon: "󰐥", label: "Shutdown",cmd: ["systemctl", "poweroff"],        confirm: true  },
    ]

    property var aboutRows: [
        { label: "Host",   value: root.hostname },
        { label: "OS",     value: root.os       },
        { label: "Kernel", value: root.kernel   },
        { label: "Uptime", value: root.uptime   },
    ]

    // ══════════════════════════════════════════════════════════════════════

    Variants {
        model: Quickshell.screens
        delegate: Component {
            PanelWindow {
                id: win
                required property var modelData
                visible: root.showPopup

                screen: modelData
                color: "transparent"
                exclusionMode: PanelWindow.ExclusionMode.Ignore
                focusable: true
                implicitWidth: 340
                implicitHeight: Math.min(mainColumn.implicitHeight + 28, 600)

                Rectangle {
                    anchors.fill: parent
                    color: Theme.bg
                    focus: true
                    border.width: 1
                    border.color: Theme.primary
                    radius: 8

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) root.closeWin()
                    }

                    ColumnLayout {
                        id: mainColumn
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 14

                        // ── Header ─────────────────────────────────────────
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "󰒓"
                                color: Theme.primary
                                font.family: Theme.fontFamily
                                font.pixelSize: 16
                            }

                            Text {
                                text: "Settings"
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.bold: true
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "✕"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 12

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onEntered: parent.color = Theme.error
                                    onExited: parent.color = Theme.muted
                                    onClicked: root.closeWin()
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Theme.primary
                            opacity: 0.15
                        }

                        // ── Section: System ────────────────────────────────
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

                                    implicitWidth: 48
                                    implicitHeight: 52
                                    radius: 8
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
                                            if (modelData.confirm)
                                                root.confirmAction(modelData.cmd.join(" "), modelData.label)
                                            else
                                                Quickshell.execDetached(modelData.cmd)
                                        }
                                    }
                                }
                            }
                        }

                        // ── Confirm dialog ──────────────────────────────────
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
                                            actionProc.command = ["sh", "-c", root.pendingAction]
                                            actionProc.running = true
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

                        // ── Section: Network ────────────────────────────────
                        Text {
                            text: "Network"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                            opacity: 0.6
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            radius: 6
                            color: ma.containsMouse ? Theme.surfaceLighter : Theme.surface
                            border.width: 1
                            border.color: Theme.surfaceLighter

                            property alias ma: ma

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
                                    Quickshell.execDetached(Config.impalaCmd)
                                    root.closeWin()
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Theme.primary
                            opacity: 0.15
                        }

                        // ── Section: About ──────────────────────────────────
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
        }
    }
}
