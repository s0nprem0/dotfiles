import Quickshell
import QtQuick
import QtQuick.Layouts

import "../../service"

ColumnLayout {
    id: root

    property bool audioMuted: false
    property bool wifiEnabled: false
    property bool btEnabled: false
    property string diagCpu: ""
    property string diagMem: ""
    property string diagDisk: ""
    property string timeShort24h: ""

    signal toggleNetworkPopup()
    signal muteToggled()

    Layout.fillWidth: true
    spacing: 4

    Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Theme.primary
        opacity: 0.15
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: root.diagCpu !== ""

        Text {
            text: "󰔄 " + root.diagCpu
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 7
        }

        Text {
            text: root.diagMem
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 7
        }

        Text {
            text: root.diagDisk
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 7
        }

        Item { Layout.fillWidth: true }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        Item {
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            Text {
                id: audioIcon
                anchors.centerIn: parent
                text: root.audioMuted ? "󰝟" : "󰕾"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 16
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onEntered: audioIcon.color = Theme.primary
                onExited: audioIcon.color = Theme.muted
                onClicked: {
                    Quickshell.execDetached(["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"])
                    root.muteToggled()
                }
            }
        }

        Item {
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            Text {
                id: wifiIcon
                anchors.centerIn: parent
                text: root.wifiEnabled ? "󰖩" : "󰖪"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 16
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onEntered: wifiIcon.color = Theme.primary
                onExited: wifiIcon.color = Theme.muted
                onClicked: root.toggleNetworkPopup()
            }
        }

        Item {
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            Text {
                id: btIcon
                anchors.centerIn: parent
                text: root.btEnabled ? "󰂯" : "󰂲"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 16
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onEntered: btIcon.color = Theme.primary
                onExited: btIcon.color = Theme.muted
                onClicked: {
                    Quickshell.execDetached(["bluetoothctl", "power", root.btEnabled ? "off" : "on"])
                }
            }
        }

        Item {
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            Text {
                id: brightnessIcon
                anchors.centerIn: parent
                text: "󰃠"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 16
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onEntered: brightnessIcon.color = Theme.primary
                onExited: brightnessIcon.color = Theme.muted
                onClicked: (mouse) => {
                    if (mouse.button === Qt.LeftButton)
                        Quickshell.execDetached([Theme.bin("osdctl"), "brightness", "up"])
                    else if (mouse.button === Qt.RightButton)
                        Quickshell.execDetached([Theme.bin("osdctl"), "brightness", "down"])
                    else if (mouse.button === Qt.MiddleButton)
                        Quickshell.execDetached([Theme.bin("osdctl"), "brightness", "set", "50"])
                }
            }
        }

        Item { Layout.fillWidth: true }

        Text {
            text: root.timeShort24h
            color: Theme.primary
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.bold: true
        }
    }
}
