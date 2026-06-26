import "../components"
import "../service"
import QtQuick
import Quickshell
import Quickshell.Io

BarModule {
    id: root

    property bool caffeineActive: false

    implicitWidth: cafIcon.implicitWidth + 12
    tooltipText: root.caffeineActive ? "Caffeine: ON (click to disable)" : "Caffeine: OFF (click to enable)"

    function toggleCaffeine() {
        root.caffeineActive = !root.caffeineActive;
        caffeineToggleProc.command = [Theme.bin("caffeine"), "toggle"];
        caffeineToggleProc.running = true;
    }

    DataModule {
        id: caffeineData
        path: Theme.bin("caffeine")
        args: ["status"]
        interval: 5000
        onDataReceived: function(j) {
            root.caffeineActive = j.active === true;
        }
    }

    Text {
        id: cafIcon
        anchors.centerIn: parent
        text: root.caffeineActive ? "" : "󰅶"
        color: root.caffeineActive ? Theme.warning : (mA.containsMouse ? Theme.primary : Theme.muted)
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize2xl
    }

    Process {
        id: caffeineToggleProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(this.text.trim());
                    root.caffeineActive = d.active === true;
                } catch (e) { console.warn("Caffeine: parse error", e); }
            }
        }
    }

    Binding {
        target: root
        property: "error"
        value: caffeineData.hasError
    }

    Binding {
        target: root
        property: "loading"
        value: caffeineData.loading
    }

    Connections {
        function onClicked(mouse) {
            if (mouse.button === Qt.LeftButton)
                root.toggleCaffeine();
        }
        target: mA
    }
}
