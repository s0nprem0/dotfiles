import "../components"
import "../service"
import QtQuick
import Quickshell.Services.SystemTray

BarModule {
    id: root

    property var trayPopupRef: null

    implicitWidth: 28
    tooltipText: "System Tray (" + SystemTray.items.length + " items)"
    visible: SystemTray.items.length > 0
    mA.onClicked: {
        if (root.trayPopupRef)
            root.trayPopupRef.showPopup = !root.trayPopupRef.showPopup;
    }

    Text {
        anchors.centerIn: parent
        text: "󰟸"
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }
}
