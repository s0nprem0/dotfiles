import "../service"
import QtQuick

Text {
    id: root

    property bool muted: false
    property bool enabled: true
    property string icon: "󰝟"
    property string altIcon: "󰕾"
    property color iconColor: Theme.primary

    text: root.muted ? root.icon : root.altIcon
    color: root.iconColor
    font.family: Theme.fontFamily
    font.pixelSize: 11
    renderType: Text.NativeRendering
    opacity: root.muted ? 0.5 : 1.0
    cursorShape: Qt.PointingHandCursor

    enabled: root.enabled
    hoverEnabled: true

    signal clicked()

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Behavior on opacity {
        NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
    }

    Behavior on color {
        ColorAnimation { duration: 150; easing.type: Easing.InOutQuad }
    }
}