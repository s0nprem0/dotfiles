import "../components"
import "../service"
import QtQuick
import Quickshell

BarModule {
    id: root

    property bool hasItems: false
    property var clipboardPopupRef: null

    implicitWidth: clipText.implicitWidth + 12
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    tooltipText: root.hasItems ? "Clipboard Manager" : "Clipboard (empty)"

    Connections {
        function onClicked(mouse) {
            if (mouse.button === Qt.LeftButton) {
                if (root.clipboardPopupRef)
                    root.clipboardPopupRef.showPopup = !root.clipboardPopupRef.showPopup;

            }
        }

        target: mA
    }

    DataModule {
        id: clipData

        path: Theme.bin("get_clipboard_status.sh")
        interval: 30000
        onDataReceived: function(j) {
            root.hasItems = j.hasItems === true;
        }
    }

    Binding {
        target: root
        property: "error"
        value: clipData.hasError
    }

    Binding {
        target: root
        property: "loading"
        value: clipData.loading
    }

    Text {
        id: clipText

        anchors.centerIn: parent
        text: root.hasItems ? "󰅆" : "󰅈"
        color: root.hasItems ? Theme.fg : Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLg
    }

}
