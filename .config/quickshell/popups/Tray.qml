import "../service"
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray

PopupPanel {
    id: root

    anchorSide: "right"
    panelWidth: 280

    contentComponent: Component {
        FocusScope {
            anchors.fill: parent

            ColumnLayout {
                anchors.fill: parent
                spacing: 6

                Text {
                    text: "󰟸  System Tray"
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                    Layout.bottomMargin: 4
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "transparent"

                    ListView {
                        id: trayList
                        anchors.fill: parent
                        clip: true
                        model: SystemTray.items
                        spacing: 2

                        Text {
                            anchors.centerIn: parent
                            text: "No tray items"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            visible: SystemTray.items.length === 0
                        }

                        delegate: Rectangle {
                            required property var modelData

                            width: trayList.width
                            height: 28
                            color: itemMouse.containsMouse ? Qt.alpha(Theme.primary, 0.12) : "transparent"
                            radius: 4

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                Image {
                                    id: trayIcon
                                    width: 16
                                    height: 16
                                    source: modelData.icon
                                    asynchronous: true
                                    sourceSize.width: 16
                                    sourceSize.height: 16
                                    visible: status === Image.Ready
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Text {
                                    text: modelData.title || "Unknown"
                                    color: Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }

                            MouseArea {
                                id: itemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.LeftButton) {
                                        modelData.activate();
                                    } else if (mouse.button === Qt.RightButton) {
                                        if (modelData.menu && modelData.hasMenu)
                                            modelData.menu.popup();
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
