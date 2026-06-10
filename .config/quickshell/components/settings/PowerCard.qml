import QtQuick
import QtQuick.Layouts

import "../../service"

Rectangle {
    id: root

    property string activeProfile: "balanced"
    property int chargeLimit: 80

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

        spacing: 12

        Text {
            text: "Power"

            color: Theme.fg

            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.bold: true
        }

        Text {
            text: "Power Mode"

            color: Theme.muted

            font.family: Theme.fontFamily
            font.pixelSize: 10
        }

        RowLayout {
            Layout.fillWidth: true

            spacing: 6

            Repeater {
                model: [
                    {
                        label: "Saver",
                        profile: "power-saver"
                    },
                    {
                        label: "Balanced",
                        profile: "balanced"
                    },
                    {
                        label: "Performance",
                        profile: "performance"
                    }
                ]

                delegate: Rectangle {
                    required property var modelData

                    Layout.fillWidth: true

                    height: 32

                    radius: 6

                    color: root.activeProfile === modelData.profile
                        ? Theme.primary
                        : Theme.surfaceLighter

                    border.width: 1
                    border.color: Qt.alpha(Theme.primary, 0.15)

                    Text {
                        anchors.centerIn: parent

                        text: modelData.label

                        color: root.activeProfile === modelData.profile
                            ? Theme.bg
                            : Theme.fg

                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.bold: root.activeProfile === modelData.profile
                    }

                    MouseArea {
                        anchors.fill: parent

                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            root.activeProfile =
                                modelData.profile
                        }
                    }
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

            Text {
                text: "Battery Charge Limit"

                color: Theme.muted

                font.family: Theme.fontFamily
                font.pixelSize: 10
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: root.chargeLimit + "%"

                color: Theme.primary

                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.bold: true
            }
        }
    }
}