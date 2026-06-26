import "../components"
import "../service"
import QtQuick
import Quickshell
import Quickshell.Io

BarModule {
    id: root

    property var themePickerPopupRef: null

    implicitWidth: themeIcon.implicitWidth + 12
    tooltipText: "Theme Presets"

    Text {
        id: themeIcon

        anchors.centerIn: parent
        text: "󰸌"
        color: mA.containsMouse ? Theme.primary : Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize3xl
    }

    Connections {
        function onClicked(mouse) {
            if (mouse.button === Qt.LeftButton && root.themePickerPopupRef)
                root.themePickerPopupRef.showPopup = !root.themePickerPopupRef.showPopup;

        }

        target: mA
    }

}
