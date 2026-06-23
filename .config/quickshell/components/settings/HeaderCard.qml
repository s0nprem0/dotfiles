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
    color: "transparent"
    border.width: 1
    border.color: Theme.primary
    implicitHeight: content.implicitHeight + 24

    ColumnLayout {
        id: content

        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Rectangle {
                width: 48
                height: 48
                radius: 0
                color: Theme.primary

                Text {
                    anchors.centerIn: parent
                    text: "󰣇"
                    color: Theme.bg
                    font.family: Theme.fontFamily
                    font.pixelSize: 28
                }

            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: root.hostname.toUpperCase()
                    color: Theme.primary
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: root.os.toUpperCase()
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

            }

        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.primary
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: root.charging ? "󱐋 " + root.batteryPercent + "%" : "󰁹 " + root.batteryPercent + "%"
                color: root.charging ? Theme.green : Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.bold: true
            }

            Text {
                text: "•"
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }

            Text {
                text: root.charging ? "CHARGING" : "DISCHARGING"
                color: root.charging ? Theme.green : Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.bold: true
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: "󰔚 " + root.uptime.toUpperCase()
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.bold: true
            }

        }

    }

}
