import "../../service"
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property var aboutRows: []

    color: "transparent"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Text {
            text: "ABOUT"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSm
            color: Theme.primary
            font.bold: true
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.bg
            border.width: 1
            border.color: Theme.primary

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                Repeater {
                    model: root.aboutRows

                    delegate: RowLayout {
                        required property var modelData

                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: modelData.label.toUpperCase() + ":"
                            Layout.preferredWidth: 56
                            color: Theme.primary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            font.bold: true
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Theme.primary
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text: modelData.value.toUpperCase()
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            font.bold: true
                        }

                    }

                }

            }

        }

        Item {
            Layout.fillHeight: true
        }

    }

}
