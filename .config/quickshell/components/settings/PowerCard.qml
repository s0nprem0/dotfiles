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
    border.color: Theme.primaryAlpha03
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
            font.pixelSize: Theme.fontSize3xl
            font.bold: true
        }

        Text {
            text: "Power Mode"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLg
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
                        font.pixelSize: Theme.fontSizeLg
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
            color: Theme.primaryAlpha03
        }

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Battery Charge Limit"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLg
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: root.chargeLimit + "%"
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXl
                font.bold: true
            }

        }

    }

}
