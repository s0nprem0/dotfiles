import "../components"
import "../service"
import QtQuick
import QtQuick.Controls // Required for ToolTip
import QtQuick.Layouts
import Quickshell.Services.SystemTray

BarModule {
    id: root

    // Let the Layout calculate the width automatically based on its children + margins
    implicitWidth: trayLayout.implicitWidth + 12
    visible: trayRepeater.count > 0

    RowLayout {
        id: trayLayout

        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: 2

        Repeater {
            id: trayRepeater

            model: SystemTray.items

            Item {
                required property var modelData

                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                // Show standard tooltips for apps that provide them
                ToolTip.visible: mouseArea.containsMouse
                ToolTip.text: modelData.title || ""
                ToolTip.delay: 500

                // Subtle highlight on hover
                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    color: Qt.alpha(Theme.fg, 0.1)
                    visible: mouseArea.containsMouse
                }

                Image {
                    id: trayIcon

                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    source: modelData.icon
                    asynchronous: true
                    sourceSize.width: 16
                    sourceSize.height: 16
                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    text: modelData.title ? modelData.title.charAt(0).toUpperCase() : "?"
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    // Only show fallback text on error/null, not during loading
                    visible: trayIcon.status === Image.Error || trayIcon.status === Image.Null
                }

                MouseArea {
                    id: mouseArea

                    anchors.fill: parent
                    hoverEnabled: true
                    // Allow the MouseArea to listen for Left, Right, and Middle clicks
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton) {
                            // Left click: Open the app window
                            modelData.activate();
                        } else if (mouse.button === Qt.RightButton) {
                            // Right click: Open the context menu
                            if (modelData.menu && modelData.hasMenu)
                                modelData.menu.popup();

                        } else if (mouse.button === Qt.MiddleButton) {
                            // Middle click: Standard SNI secondary action (e.g., mute audio)
                            if (typeof modelData.secondaryActivate === "function")
                                modelData.secondaryActivate();

                        }
                    }
                }

            }

        }

    }

}
