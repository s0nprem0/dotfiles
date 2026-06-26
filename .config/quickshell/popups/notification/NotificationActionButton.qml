import "../../service"
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    required property var action
    property int btnHeight: 22
    property int btnRadius: 4

    signal invoked()

    function invokeAction() {
        root.action.invoke();
        root.invoked();
    }

    implicitHeight: root.btnHeight
    implicitWidth: label.implicitWidth + 10
    color: mouseArea.containsMouse || activeFocus ? Theme.primaryAlpha02 : Theme.surfaceLighter
    radius: root.btnRadius
    border.width: activeFocus ? 2 : 1
    border.color: activeFocus ? Theme.primary : (mouseArea.containsMouse ? Theme.primaryAlpha04 : Theme.primaryAlpha015)
    focusPolicy: Qt.TabFocus
    Keys.onReturnPressed: invokeAction()
    Keys.onSpacePressed: invokeAction()

    Text {
        id: label

        anchors.centerIn: parent
        text: root.action.label || "unknown"
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSm
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: {
            root.invokeAction();
        }
    }

}
