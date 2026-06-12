import "../../service"
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    required property string hostname
    required property string os
    required property string uptime
    required property string batteryPercent
    required property bool charging

    Layout.fillWidth: true
    radius: 0
    color: Theme.surface
    border.width: 1
    border.color: Qt.alpha(Theme.primary, 0.15)
    implicitHeight: content.implicitHeight + 24

    ColumnLayout {
        id: content

        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true

            Rectangle {
                width: 36
                height: 36
                radius: 0
                color: Qt.alpha(Theme.primary, 0.12)

                Text {
                    anchors.centerIn: parent
                    text: "󰣇"
                    color: Theme.primary
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                }

            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: root.hostname
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: root.os
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

            }

        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.alpha(Theme.primary, 0.12)
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: root.charging ? "󱐋 " + root.batteryPercent + "%" : "󰁹 " + root.batteryPercent + "%"
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }

            Text {
                text: "•"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }

            Text {
                text: root.charging ? "Charging" : "Discharging"
                color: root.charging ? Theme.green : Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: "󰔚 " + root.uptime
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }

        }

    }

    Behavior on color {
        ColorAnimation {
            duration: 150
        }

    }

}
