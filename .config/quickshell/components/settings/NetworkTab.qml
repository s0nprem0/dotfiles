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
        anchors.margins: 16
        spacing: 16

        Text {
            text: "Network Tools"
            font.pixelSize: 14
            color: Theme.fg
            font.bold: true
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            color: nwMa.containsMouse ? Theme.surfaceLighter : Theme.surface
            border.width: 1
            border.color: Theme.primary

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                Text { text: "󰤨"; color: Theme.primary; font.pixelSize: 18 }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 2
                    Text { text: "WiFi Manager"; color: Theme.fg; font.pixelSize: 11; font.bold: true }
                    Text { text: "Launch impala"; color: Theme.muted; font.pixelSize: 9 }
                }
                Text { text: "Open"; color: Theme.primary; font.pixelSize: 10; font.bold: true }
            }

            MouseArea {
                id: nwMa
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: root.openImpala()
            }
        }
    }
}
