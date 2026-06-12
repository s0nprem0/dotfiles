import "../service"
import QtQuick
import Quickshell

PanelWindow {
    id: root

    default property alias content: contentArea.data
    property int barHeight: Theme.barHeight

    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: barHeight
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Theme.bg, Theme.barOpacity)

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 2
            color: Qt.alpha(Theme.primary, 0.35)
        }

    }

    Item {
        id: contentArea

        anchors.fill: parent
    }

}
