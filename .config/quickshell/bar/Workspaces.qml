import "../components"
import "../service"
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

BarModule {
    id: root

    property var wsMap: ({})
    property var workspaceIds: ([])

    tooltipText: ""
    implicitWidth: wsRow.implicitWidth + 8

    function refreshWorkspaces() {
        let map = {};
        let ids = [];
        for (const ws of Hyprland.workspaces.values) {
            map[ws.id] = ws;
            ids.push(ws.id);
        }
        ids.sort((a, b) => a - b);
        wsMap = map;
        workspaceIds = ids;
    }

    Timer {
        id: debounceTimer
        interval: 150
        onTriggered: root.refreshWorkspaces()
    }

    RowLayout {
        id: wsRow
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: 2

        Repeater {
            model: root.workspaceIds

            delegate: Rectangle {
                id: wsBtn

                required property int modelData
                readonly property int wsId: modelData
                readonly property var ws: root.wsMap[wsId]
                readonly property bool exists: ws != null
                readonly property bool isFocused: exists && Hyprland.focusedWorkspace && ws.id === Hyprland.focusedWorkspace.id
                readonly property bool isActive: exists && ws.windows > 0
                readonly property bool isUrgent: exists && ws.urgent

                implicitWidth: 24
                implicitHeight: 24
                radius: 0
                color: {
                    if (isFocused)
                        return Theme.primary;
                    if (isUrgent)
                        return Qt.alpha(Theme.warning, 0.25);
                    if (isActive)
                        return Qt.alpha(Theme.primary, 0.12);
                    if (mouseArea.containsMouse)
                        return Qt.alpha(Theme.fg, 0.08);
                    return "transparent";
                }
                scale: mouseArea.pressed ? 0.92 : (isFocused ? 1.05 : 1)

                Text {
                    anchors.centerIn: parent
                    text: wsId
                    color: {
                        if (isFocused)
                            return Theme.bg;
                        if (exists)
                            return Theme.fg;
                        return Qt.alpha(Theme.fg, 0.4);
                    }
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLg
                    font.bold: isFocused
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 2
                    visible: exists && !isFocused
                    color: isActive ? Theme.primary : Qt.alpha(Theme.fg, 0.35)
                }

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Hyprland.dispatch("workspace", String(wsId))
                }

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                Behavior on scale {
                    NumberAnimation { duration: 120 }
                }
            }
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse
        onWheel: (event) => {
            if (event.angleDelta.y > 0)
                Hyprland.dispatch("workspace", "e-1");
            else if (event.angleDelta.y < 0)
                Hyprland.dispatch("workspace", "e+1");
        }
    }

    Connections {
        function onRawEvent(event) {
            const refreshEvents = ["workspacev2", "createworkspacev2", "destroyworkspacev2", "moveworkspacev2"];
            if (refreshEvents.includes(event.name))
                debounceTimer.restart();
        }
        target: Hyprland
    }

    Component.onCompleted: root.refreshWorkspaces()
}
