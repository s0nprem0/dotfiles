import "../service"
import QtQuick

Rectangle {
    id: root

    property alias mA: mA
    property alias tooltipText: tooltipLabel.text
    property bool tooltipVisible: tooltipLabel.text.length > 0
    property int acceptedButtons: Qt.LeftButton
    property bool tooltipBelow: true
    property bool loading: false
    property bool error: false

    height: 28
    color: root.error ? Qt.alpha("#e06c75", 0.3) : mA.containsMouse ? Theme.primaryAlpha02 : Qt.alpha(Theme.surface, 0.4)
    border.color: mA.containsMouse ? Theme.primaryAlpha03 : Theme.primaryAlpha01
    border.width: 1

    Rectangle {
        id: tooltip

        anchors.top: root.tooltipBelow ? parent.bottom : undefined
        anchors.bottom: !root.tooltipBelow ? parent.top : undefined
        anchors.topMargin: root.tooltipBelow ? 4 : 0
        anchors.bottomMargin: !root.tooltipBelow ? 4 : 0
        anchors.horizontalCenter: parent.horizontalCenter
        height: 20
        width: tooltipLabel.width + 12
        radius: 0
        color: Qt.alpha(Theme.surface, 0.9)
        border.color: Theme.primaryAlpha02
        border.width: 1
        opacity: (mA.containsMouse && root.tooltipVisible) ? 1 : 0
        visible: opacity > 0

        Text {
            id: tooltipLabel

            anchors.centerIn: parent
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeMd
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }

        }

    }

    MouseArea {
        id: mA

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: root.acceptedButtons
        cursorShape: Qt.PointingHandCursor
    }

    Behavior on color {
        ColorAnimation {
            duration: 80
        }

    }

    Behavior on border.color {
        ColorAnimation {
            duration: 80
        }

    }

}
