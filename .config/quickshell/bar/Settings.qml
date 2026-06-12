import "../components"
import "../service"
import QtQuick

BarModule {
    id: root

    property var settingsPopupRef: null

    implicitWidth: 28
    tooltipText: "Settings"
    mA.onClicked: {
        if (root.settingsPopupRef)
            root.settingsPopupRef.showPopup = !root.settingsPopupRef.showPopup;

    }

    Text {
        anchors.centerIn: parent
        text: "󰒓"
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }

}
