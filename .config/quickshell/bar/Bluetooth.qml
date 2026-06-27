import "../components"
import "../service"
import QtQuick
import Quickshell
import Quickshell.Io

BarModule {
    id: root

    property bool btEnabled: false
    property bool hasConnected: false
    property string btTooltip: ""

    implicitWidth: btText.implicitWidth + 12
    acceptedButtons: Qt.LeftButton
    tooltipText: root.btTooltip

    DataModule {
        id: btData

        path: Theme.bin("get_bluetooth_status")
        interval: 30000
        onDataReceived: function(j) {
            root.btEnabled = j.enabled ?? false;
            root.hasConnected = false;
            var names = [];
            var devices = j.devices ?? [];
            for (var i = 0; i < devices.length; i++) {
                var dev = devices[i];
                if (dev && dev.connected) {
                    root.hasConnected = true;
                    names.push(dev.name);
                }
            }
            root.btTooltip = root.hasConnected ? names.join(", ") : (root.btEnabled ? "No devices" : "Bluetooth off");
        }
    }

    Binding {
        target: root
        property: "error"
        value: btData.hasError
    }

    Binding {
        target: root
        property: "loading"
        value: btData.loading
    }

    Process {
        id: btToggle
    }

    Connections {
        function onRunningChanged() {
            if (!btToggle.running)
                btData.refresh();

        }

        target: btToggle
    }

    Connections {
        function onClicked(mouse) {
            var nextPower = !root.btEnabled;
            btToggle.command = ["bluetoothctl", "power", nextPower ? "on" : "off"];
            btToggle.running = true;
            root.btEnabled = nextPower;
            Quickshell.execDetached([Theme.bin("osdctl"), "show", nextPower ? "Bluetooth on" : "Bluetooth off", "warn", "1500"]);
        }

        target: mA
    }

    Text {
        id: btText

        anchors.centerIn: parent
        text: root.hasConnected ? "󰂯" : "󰂲"
        color: root.btEnabled && root.hasConnected ? Theme.primary : Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLg
        renderType: Text.NativeRendering
    }

}
