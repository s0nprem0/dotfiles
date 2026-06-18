import QtQuick
import QtQuick.Layouts
import Quickshell

Rectangle {
    id: root

    property string activeProfile: "balanced"
    property var availableProfiles: []

    signal setProfile(string profile)

    color: "transparent"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            color: Theme.surface
            border.width: 1
            border.color: Theme.primary

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 12

                Text {
                    text: "Power Profile"
                    font.pixelSize: 14
                    color: Theme.fg
                    font.bold: true
                }

                RowLayout {
                    spacing: 8
                    Repeater {
                        model: root.availableProfiles
                        delegate: Rectangle {
                            required property string modelData
                            Layout.preferredWidth: 110
                            Layout.preferredHeight: 48
                            color: modelData === root.activeProfile ? Theme.primary : Theme.surfaceLighter
                            border.width: 1
                            border.color: Theme.primary

                            Text {
                                anchors.centerIn: parent
                                text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                                color: modelData === root.activeProfile ? Theme.bg : Theme.fg
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.setProfile(modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
