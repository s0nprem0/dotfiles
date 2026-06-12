import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import "../service"

Scope {
    id: root

    readonly property string statePath: "file://" + Theme.home + "/.cache/quickshell/osd_state.json"

    property string message: ""
    property string kind: "info"

    function getPercentage(msg) {
        var match = msg.match(/(\d+)%/)
        return match ? parseInt(match[1]) : -1
    }

    function getPrefix(msg) {
        var match = msg.match(/^(.*?)\s+\d+%/)
        return match ? match[1] : msg
    }

    function getPercentText(msg) {
        var match = msg.match(/(\d+%)/)
        return match ? match[1] : ""
    }

    function getIcon(msg) {
        var lower = msg.toLowerCase()
        if (lower.includes("volume")) {
            if (lower.includes("mute")) return "󰝟"
            return "󰕾"
        }
        if (lower.includes("mic")) {
            if (lower.includes("mute")) return "󰍭"
            return "󰍬"
        }
        if (lower.includes("kbd brightness") || lower.includes("kbdbrightness")) return "󰌶"
        if (lower.includes("brightness")) return "󰃠"
        return ""
    }

    function getIconColor(msg) {
        var lower = msg.toLowerCase()
        if (lower.includes("mute")) return Theme.error
        if (root.kind === "good") return Theme.green
        if (root.kind === "warn") return Theme.warning
        if (root.kind === "bad") return Theme.error
        if (lower.includes("brightness") || lower.includes("volume")) return Theme.primary
        return Theme.fg
    }

    function defaultState() {
        return { visible: false, text: "", kind: "info", timeout_ms: 1200 }
    }

    function readState() {
        try {
            var raw = stateFile.text()
            if (!raw || raw.trim() === "") return defaultState()
            var parsed = JSON.parse(raw)
            return {
                visible: parsed.visible !== false,
                text: String(parsed.text ?? ""),
                kind: String(parsed.kind ?? "info"),
                timeout_ms: parsed.timeout_ms ?? 1200
            }
        } catch (e) {
            return defaultState()
        }
    }

    function refreshState() {
        var state = readState()
        message = state.text
        kind = state.kind
        if (state.visible && state.text.length > 0) {
            slide.show = true
            hideTimer.interval = state.timeout_ms || 1200
            hideTimer.restart()
        } else {
            slide.closeAnim()
            hideTimer.stop()
        }
    }

    Timer {
        id: hideTimer
        interval: 1200
        repeat: false
        onTriggered: { slide.closeAnim() }
    }

    FileView {
        id: stateFile
        path: root.statePath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.refreshState()
    }

    Component.onCompleted: stateFile.reload()

    SlideAnimator {
        id: slide
        slideFrom: -50
        slideTo: 5
        introDuration: 120
        exitDuration: 100
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: win

                required property var modelData

                screen: modelData
                color: "transparent"
                exclusionMode: PanelWindow.ExclusionMode.Ignore
                WlrLayershell.namespace: "osd"
                visible: slide.show || slide.active

                implicitWidth: 280
                implicitHeight: mainLayout.implicitHeight + 16

                anchors {
                    top: true
                }

                margins {
                    top: slide.animSlide
                }

                Rectangle {
                    anchors.fill: parent
                    opacity: slide.animOpacity
                    color: Qt.alpha(Theme.bg, 0.85)
                    border.width: 1
                    border.color: root.kind === "good" ? Theme.primary : root.kind === "bad" ? Theme.error : root.kind === "warn" ? Theme.warning : Theme.primary
                    radius: 0
                    antialiasing: true

                    Column {
                        id: mainLayout
                        anchors.centerIn: parent
                        spacing: 6
                        width: parent.width - 20

                        // Percentage mode: icon + label + percent, then full-width slider
                        Column {
                            spacing: 6
                            width: parent.width
                            visible: root.getPercentage(root.message) !== -1

                            Row {
                                spacing: 6
                                anchors.horizontalCenter: parent.horizontalCenter

                                Text {
                                    text: root.getIcon(root.message)
                                    color: root.getIconColor(root.message)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 14
                                    renderType: Text.NativeRendering
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: text !== ""
                                }

                                Text {
                                    text: root.getPrefix(root.message)
                                    color: Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 14
                                    renderType: Text.NativeRendering
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: root.getPercentText(root.message)
                                    color: root.getIconColor(root.message)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 14
                                    font.bold: true
                                    renderType: Text.NativeRendering
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            BlockSlider {
                                width: parent.width
                                currentVal: root.getPercentage(root.message) / 100
                                height: 6
                                fillColor: root.getIconColor(root.message)
                            }
                        }

                        // Fallback text mode: icon + message
                        Row {
                            spacing: 6
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: root.getPercentage(root.message) === -1

                            Text {
                                id: fallbackIcon
                                text: root.getIcon(root.message)
                                color: root.getIconColor(root.message)
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                renderType: Text.NativeRendering
                                visible: text !== ""
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                id: fallbackLabel
                                text: root.message
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                renderType: Text.NativeRendering
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                }
            }
        }
    }
}
