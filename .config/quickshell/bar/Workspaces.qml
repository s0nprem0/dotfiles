import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

import "../service"

Rectangle {
    id: root

    readonly property int maxWorkspaces: 20

    // Hyprland.workspaces is isPropertyConstant, so we mirror the count into
    // a regular property that the Repeater model can react to.
    property int workspaceCount: 0

    // Lookup map to avoid O(N*M) linear scans per delegate
    property var wsMap: ({})

    function refreshMap() {
        var map = {}
        for (const w of Hyprland.workspaces.values) {
            map[w.id] = w
        }
        root.wsMap = map
    }

    color: Qt.alpha(Theme.surface, 0.3)
    border.color: Qt.alpha(Theme.primary, 0.1)
    border.width: 1
    radius: 0

    height: 28
    implicitWidth: wsRow.implicitWidth + 8

    RowLayout {
        id: wsRow

        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4

        spacing: 2

        Repeater {
            model: Math.min(root.maxWorkspaces, root.workspaceCount)

            delegate: Rectangle {
                id: wsBtn

                required property int index

                readonly property int wsId: {
                    var keys = Object.keys(root.wsMap).map(k => parseInt(k)).sort((a, b) => a - b)
                    return index < keys.length ? keys[index] : index + 1
                }

                property var ws: root.wsMap[wsId] || null

                readonly property bool exists: ws !== null
                readonly property bool isFocused: exists && ws.id === Hyprland.focusedWorkspace.id
                readonly property bool isActive: exists && ws.windows > 0
                readonly property bool isUrgent: exists && ws.urgent

                implicitWidth: 24
                implicitHeight: 24

                radius: 0

                color: {
                    if (isFocused)
                        return Theme.primary

                    if (isUrgent)
                        return Qt.alpha(Theme.warning, 0.25)

                    if (isActive)
                        return Qt.alpha(Theme.primary, 0.12)

                    if (mouseArea.containsMouse)
                        return Qt.alpha(Theme.fg, 0.08)

                    return "transparent"
                }

                scale: mouseArea.pressed
                    ? 0.92
                    : (isFocused ? 1.05 : 1.0)

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: 120
                    }
                }

                Text {
                    anchors.centerIn: parent

                    text: wsId

                    color: {
                        if (isFocused)
                            return Theme.bg

                        if (exists)
                            return Theme.fg

                        return Qt.alpha(Theme.fg, 0.4)
                    }

                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.bold: isFocused
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter

                    width: 4
                    height: 4
                    radius: 0

                    visible: exists && !isFocused

                    color: isActive
                        ? Theme.primary
                        : Qt.alpha(Theme.fg, 0.45)
                }

                MouseArea {
                    id: mouseArea

                    anchors.fill: parent
                    hoverEnabled: true
                    propagateComposedEvents: false

                    onClicked: {
                        Hyprland.dispatch(
                            "workspace",
                            String(wsId)
                        )
                    }
                }
            }
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse

        onWheel: event => {
            if (event.angleDelta.y > 0)
                Hyprland.dispatch("workspace", "e-1")
            else if (event.angleDelta.y < 0)
                Hyprland.dispatch("workspace", "e+1")
        }
    }

    Timer {
        id: refreshTimer
        interval: 50
        onTriggered: {
            root.workspaceCount = Hyprland.workspaces.values.length
            root.refreshMap()
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "workspacev2" || event.name === "destroyworkspacev2") {
                Hyprland.refreshWorkspaces()
                refreshTimer.restart()
            }
        }
    }

    Component.onCompleted: {
        root.workspaceCount = Hyprland.workspaces.values.length
        root.refreshMap()
    }
}
