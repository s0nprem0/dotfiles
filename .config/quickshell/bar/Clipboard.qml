import Quickshell
import QtQuick
import "../components"
import "../service"

BarModule {
    id: root

    implicitWidth: clipText.implicitWidth + 12

    property bool hasItems: false
    property var clipboardPopupRef: null

    acceptedButtons: Qt.LeftButton | Qt.RightButton

    Connections {
        target: mA
        function onClicked(mouse) {
            if (mouse.button === Qt.LeftButton) {
                if (root.clipboardPopupRef)
                    root.clipboardPopupRef.showPopup = !root.clipboardPopupRef.showPopup
            }
        }
    }

    DataModule {
        id: clipData
        path: Theme.bin("get_clipboard_status.sh")
        interval: 10000
        onDataReceived: function(j) {
            root.hasItems = j.hasItems === true
        }
    }
    Binding { target: root; property: "error"; value: clipData.hasError }
    Binding { target: root; property: "loading"; value: clipData.loading }

    tooltipText: root.hasItems ? "Clipboard Manager" : "Clipboard (empty)"

    Text {
        id: clipText
        anchors.centerIn: parent
        text: root.hasItems ? "󰅆" : "󰅈"
        color: root.hasItems ? Theme.fg : Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }
}
