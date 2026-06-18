import "../components"
import "../service"
import QtQuick
import Quickshell.Services.SystemTray

BarModule {
    id: root

    property var trayPopupRef: null

    implicitWidth: Math.max(28, iconRow.implicitWidth + 8)
    tooltipText: "System Tray (" + SystemTray.items.length + " items)"
    visible: true
    mA.onClicked: {
        if (root.trayPopupRef)
            root.trayPopupRef.showPopup = !root.trayPopupRef.showPopup;

    }

    Row {
        id: iconRow

        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: SystemTray.items

            delegate: Image {
                required property var modelData

                width: 14
                height: 14
                source: modelData.icon
                fillMode: Image.PreserveAspectFit
                sourceSize.width: 14
                sourceSize.height: 14
                visible: status !== Image.Error
            }

        }

    }

}
