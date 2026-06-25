import "../service"
import QtQuick

Rectangle {
    id: root

    property var devices: []
    property string activeId: ""
    property bool enabled: true
    property int maxHeight: 200

    implicitWidth: 180
    implicitHeight: Math.min(root.maxHeight, Math.max(32, root.devices.length * 28))
    color: root.enabled ? Qt.alpha(Theme.surface, 0.5) : Qt.alpha(Theme.surface, 0.2)
    border.color: root.enabled ? Qt.alpha(Theme.primary, 0.3) : Qt.alpha(Theme.primary, 0.1)
    border.width: 1
    radius: 0

    signal deviceSelected(string id, string name)

    ListView {
        id: listView

        anchors.fill: parent
        anchors.margins: 2
        model: root.devices
        spacing: 2
        clip: true

        delegate: Rectangle {
            required property string modelData

            width: ListView.view.width - 4
            height: 24
            color: modelData.indexOf("||" + root.activeId + "||") !== -1 || modelData === root.activeId
                ? Qt.alpha(Theme.primary, 0.2)
                : hoverArea.containsMouse ? Qt.alpha(Theme.primary, 0.08) : "transparent"
            border.color: modelData.indexOf("||" + root.activeId + "||") !== -1 || modelData === root.activeId
                ? Qt.alpha(Theme.primary, 0.5)
                : Qt.alpha(Theme.primary, 0.1)
            border.width: 1

            property string deviceId: modelData.split("||")[0]
            property string deviceName: modelData.split("||")[1] || modelData

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: parent.deviceName
                color: parent.color === Qt.alpha(Theme.primary, 0.2) ? Theme.primary : Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 9
                elide: Text.ElideRight
            }

            MouseArea {
                id: hoverArea

                anchors.fill: parent
                hoverEnabled: true
                enabled: root.enabled
                cursorShape: Qt.PointingHandCursor
                onClicked: root.deviceSelected(parent.deviceId, parent.deviceName)
            }
        }
    }
}