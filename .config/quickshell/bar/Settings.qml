import QtQuick
import "../components"
import "../service"

BarModule {
    id: root
    implicitWidth: 28
    tooltipText: "Settings"
    property var settingsPopupRef: null

    Text {
        anchors.centerIn: parent
        text: "󰒓"
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: 14
    }

    mA.onClicked: {
        if (root.settingsPopupRef)
            root.settingsPopupRef.showPopup = !root.settingsPopupRef.showPopup
    }
}
