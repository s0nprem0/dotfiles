import QtQuick
import QtQuick.Layouts
import Quickshell

Rectangle {
    id: root

    property var aboutRows: []

    color: "transparent"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Text {
            text: "About This System"
            font.pixelSize: 14
            color: Theme.fg
            font.bold: true
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.surface
            border.width: 1
            border.color: Theme.primary

            ListView {
                anchors.fill: parent
                anchors.margins: 12
                model: root.aboutRows
                spacing: 8
                delegate: RowLayout {
                    width: ListView.view.width
                    spacing: 12
                    Text {
                        text: modelData.label + ":"
                        Layout.preferredWidth: 80
                        color: Theme.muted
                        font.pixelSize: 11
                    }
                    Text {
                        text: modelData.value || "—"
                        Layout.fillWidth: true
                        color: Theme.fg
                        font.pixelSize: 11
                    }
                }
            }
        }
    }
}
