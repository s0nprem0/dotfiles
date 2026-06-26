import "../../service"
import QtQuick
import QtQuick.Layouts
import Quickshell

Rectangle {
    id: root

    signal openImpala()

    color: "transparent"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Text {
            text: "NETWORK TOOLS"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSm
            color: Theme.primary
            font.bold: true
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            color: nwMa.containsMouse ? Theme.primary : Theme.bg
            border.width: 1
            border.color: Theme.primary

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 10

                Text {
                    text: "󰤨"
                    color: nwMa.containsMouse ? Theme.bg : Theme.primary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize4xl
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: "WIFI MANAGER"
                        color: nwMa.containsMouse ? Theme.bg : Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                        font.bold: true
                    }

                    Text {
                        text: "LAUNCH IMPALA"
                        color: nwMa.containsMouse ? Theme.bg : Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                        font.bold: true
                    }

                }

                Text {
                    text: "OPEN >"
                    color: nwMa.containsMouse ? Theme.bg : Theme.primary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                    font.bold: true
                }

            }

            MouseArea {
                id: nwMa

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openImpala()
            }

        }

        Item {
            Layout.fillHeight: true
        }

    }

}
