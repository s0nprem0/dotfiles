import Quickshell
import QtQuick

import ".."

PanelWindow {
    id: root

    default property alias content: contentArea.data

    property int barHeight: 36

    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: barHeight
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Theme.bg, 0.65)
        border.color: Qt.alpha(Theme.primary, 0.15)

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Qt.alpha(Theme.primary, 0.15)
        }
    }

    Item {
        id: contentArea
        anchors.fill: parent
    }
}
