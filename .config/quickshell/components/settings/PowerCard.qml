import "../../service"
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string activeProfile: "balanced"
    property int chargeLimit: 80

    signal profileSelected(string profile)

    Layout.fillWidth: true
    radius: 0
    color: Theme.surface
    border.width: 1
    border.color: Qt.alpha(Theme.primary, 0.3)
    implicitHeight: content.implicitHeight + 24

    ColumnLayout {
        id: content

        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        Text {
            text: "Power"
            color: Theme.primary
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.bold: true
        }

        Text {
            text: "Power Mode"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: [{
                    "label": "SAVER",
                    "profile": "power-saver"
                }, {
                    "label": "BALANCED",
                    "profile": "balanced"
                }, {
                    "label": "PERFORMANCE",
                    "profile": "performance"
                }]

                delegate: Rectangle {
                    required property var modelData

                    Layout.fillWidth: true
                    height: 40
                    color: root.activeProfile === modelData.profile ? Theme.primary : Theme.surfaceLighter
                    border.width: 1
                    border.color: Theme.primary

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: root.activeProfile === modelData.profile ? Theme.bg : Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.bold: root.activeProfile === modelData.profile
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.profileSelected(modelData.profile)
                    }

                }

            }

        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.alpha(Theme.primary, 0.3)
        }

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Battery Charge Limit"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: root.chargeLimit + "%"
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.bold: true
            }

        }

    }

}
