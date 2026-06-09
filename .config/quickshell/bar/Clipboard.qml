import Quickshell
import Quickshell.Io
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

    Timer {
        interval: 10000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: checkProc.running = true
    }

    Process {
        id: checkProc
        command: ["sh", "-c", "cliphist list | head -n 1 | grep -q . && echo 1 || echo 0"]
        running: false
        stdout: StdioCollector {}
        onExited: {
            root.hasItems = (stdout.text ?? "").trim() === "1"
        }
    }

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
