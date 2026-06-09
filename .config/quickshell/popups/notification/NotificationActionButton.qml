import QtQuick
import QtQuick.Layouts

import "../../service"

Rectangle {
    id: root

    required property var action
    property int btnHeight: 22
    property int btnRadius: 4
    signal invoked()

    implicitHeight: root.btnHeight
    implicitWidth: label.implicitWidth + 10
    color: mouseArea.containsMouse ? Qt.alpha(Theme.primary, 0.2) : Theme.surfaceLighter
    radius: root.btnRadius
    border.width: 1
    border.color: mouseArea.containsMouse ? Qt.alpha(Theme.primary, 0.4) : Qt.alpha(Theme.primary, 0.15)

    Text {
        id: label
        anchors.centerIn: parent
        text: root.action.label || "unknown"
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: 9
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: {
            root.action.invoke()
            root.invoked()
        }
    }
}
