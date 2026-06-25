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

    DataModule {
        id: caffeineData
        path: Theme.bin("caffeine.sh")
        args: ["status"]
        interval: 5000
        onDataReceived: function(j) {
            root.error = false;
        }
    }

    Text {
        id: themeIcon
        anchors.centerIn: parent
        text: "󰸌"
        color: root.error ? Theme.error : (mA.containsMouse ? Theme.primary : Theme.fg)
        font.family: Theme.fontFamily
        font.pixelSize: 14
    }

    Binding {
        target: root
        property: "error"
        value: caffeineData.hasError
    }

    Connections {
        function onClicked(mouse) {
            if (mouse.button === Qt.LeftButton && root.themePickerPopupRef) {
                root.themePickerPopupRef.showPopup = !root.themePickerPopupRef.showPopup;
            }
        }
        target: mA
    }
}
