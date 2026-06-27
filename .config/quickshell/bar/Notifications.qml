import "../components"
import "../service"
import QtQuick

BarModule {
    id: root

    property int notifCount: 0

    implicitWidth: notifText.implicitWidth + 12 + (badge.visible ? badge.width + 2 : 0)
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    tooltipText: NotificationState.dnd ? "Do Not Disturb" : (notifCount > 0 ? notifCount + " notification(s)" : "No notifications")

    Binding {
        target: root
        property: "notifCount"
        value: NotificationState.service ? NotificationState.service.trackedCount : 0
    }

    Connections {
        function onClicked(mouse) {
            if (mouse.button === Qt.RightButton) {
                if (NotificationState.service)
                    NotificationState.service.toggleDnd();

            } else {
                if (NotificationState.centerPopup)
                    NotificationState.centerPopup.showPopup = true;

            }
        }

        target: mA
    }

    Text {
        id: notifText

        anchors.centerIn: parent
        text: {
            if (NotificationState.dnd)
                return "󰂛";

            if (notifCount > 0)
                return "󰂚";

            return "󰂜";
        }
        color: NotificationState.dnd ? Theme.muted : (notifCount > 0 ? Theme.primary : Theme.fg)
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLg
        renderType: Text.NativeRendering
    }

    Rectangle {
        id: badge

        visible: notifCount > 0 && !NotificationState.dnd
        width: badgeText.implicitWidth + 6
        height: 12
        color: Theme.error
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: -2
        anchors.rightMargin: -2

        Text {
            id: badgeText

            anchors.centerIn: parent
            text: notifCount > 99 ? "99+" : notifCount.toString()
            color: Theme.bg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeXxs
            font.bold: true
            renderType: Text.NativeRendering
        }

    }

}
