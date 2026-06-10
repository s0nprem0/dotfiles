import Quickshell
import QtQuick
import QtQuick.Layouts

import "../../service"

RowLayout {
    id: root

    property bool audioMuted: false
    property bool wifiEnabled: false
    property bool btEnabled: false

    signal toggleNetworkPopup()

    Layout.fillWidth: true
    spacing: 12

    Item {
        Layout.preferredWidth: 28
        Layout.preferredHeight: 28
        Text {
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
            onEntered: parent.children[0].color = Theme.primary
            onExited: parent.children[0].color = Theme.muted
            onClicked: {
                Quickshell.execDetached(["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"])
            }
        }
    }

    Item {
        Layout.preferredWidth: 28
        Layout.preferredHeight: 28
        Text {
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
            onEntered: parent.children[0].color = Theme.primary
            onExited: parent.children[0].color = Theme.muted
            onClicked: root.toggleNetworkPopup()
        }
    }

    Item {
        Layout.preferredWidth: 28
        Layout.preferredHeight: 28
        Text {
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
            onEntered: parent.children[0].color = Theme.primary
            onExited: parent.children[0].color = Theme.muted
            onClicked: {
                Quickshell.execDetached(["bluetoothctl", "power", root.btEnabled ? "off" : "on"])
            }
        }
    }

    Item {
        Layout.preferredWidth: 28
        Layout.preferredHeight: 28
        Text {
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
            onEntered: parent.children[0].color = Theme.primary
            onExited: parent.children[0].color = Theme.muted
            onClicked: (mouse) => {
                if (mouse.button === Qt.LeftButton)
                    Quickshell.execDetached(["brightnessctl", "set", "5%+"])
                else if (mouse.button === Qt.RightButton)
                    Quickshell.execDetached(["brightnessctl", "set", "5%-"])
                else if (mouse.button === Qt.MiddleButton)
                    Quickshell.execDetached(["brightnessctl", "set", "50%"])
            }
        }
    }

    Item { Layout.fillWidth: true }

    Text {
        text: {
            var now = new Date()
            var h = now.getHours().toString().padStart(2, "0")
            var m = now.getMinutes().toString().padStart(2, "0")
            return h + ":" + m
        }
        color: Theme.primary
        font.family: Theme.fontFamily
        font.pixelSize: 13
        font.bold: true
    }
}
