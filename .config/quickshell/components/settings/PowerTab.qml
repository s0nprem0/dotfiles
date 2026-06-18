import "../../service"
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string activeProfile: "balanced"
    property var availableProfiles: []

    signal setProfile(string profile)

    color: "transparent"

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 8; spacing: 8

        Text { text: "POWER PROFILE"; font.family: Theme.fontFamily; font.pixelSize: 9; color: Theme.primary; font.bold: true }

        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 80
            color: Theme.bg; border.width: 1; border.color: Theme.primary

            RowLayout {
                anchors.centerIn: parent; spacing: 8
                Repeater {
                    model: root.availableProfiles
                    delegate: Rectangle {
                        required property string modelData
                        Layout.preferredWidth: 100; Layout.preferredHeight: 44
                        color: modelData === root.activeProfile ? Theme.primary : Theme.surface
                        border.width: 1; border.color: Theme.primary

                        Text {
                            anchors.centerIn: parent
                            text: modelData.toUpperCase()
                            color: modelData === root.activeProfile ? Theme.bg : Theme.fg
                            font.family: Theme.fontFamily; font.pixelSize: 9; font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root.setProfile(modelData)
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
