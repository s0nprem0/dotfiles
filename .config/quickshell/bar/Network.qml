import Quickshell
import QtQuick
import QtQuick.Layouts

import "../components"
import "../service"

BarModule {
    id: root

    implicitWidth: contentRow.implicitWidth + 24

    property bool networkConnected: false
    property bool wifiConnected: false
    property bool ethernetConnected: false
    property string networkSsid: ""
    property string networkBand: ""
    property bool vpnConnected: false
    property string vpnName: ""

    DataModule {
        id: netData
        path: Theme.bin("get_network_status")
        interval: 30000

        onDataReceived: function(j) {
            root.networkConnected = j.connected || false;
            root.wifiConnected = j.active_ssid && j.active_ssid.length > 0;
            root.ethernetConnected = j.ethernet?.connected || false;
            root.networkSsid = j.active_ssid || "";
            root.networkBand = j.active_band || "";
            root.vpnConnected = j.vpn_connected || false;
            root.vpnName = j.vpn_name || "";
            NetworkState.networkData = j;
        }
    }
    Binding { target: root; property: "error"; value: netData.hasError }
    Binding { target: root; property: "loading"; value: netData.loading }

    Connections {
        target: NetworkState
        function onRefreshRequested() { netData.refresh(); }
    }

    acceptedButtons: Qt.LeftButton | Qt.RightButton

    Connections {
        target: mA

        function onClicked(mouse) {
            if (mouse.button === Qt.RightButton) {
                Quickshell.execDetached(["nm-connection-editor"]);
            } else if (mouse.button === Qt.LeftButton) {
                if (NetworkState.popup) {
                    NetworkState.popup.showPopup = !NetworkState.popup.showPopup;
                }
            }
        }
    }

    tooltipText: {
        if (!root.networkConnected)
            return "Disconnected";

        var tip = "";
        if (root.wifiConnected)
            tip += root.networkSsid + (root.networkBand.length > 0 ? " (" + root.networkBand + ")" : "");
        if (root.ethernetConnected)
            tip += (tip.length > 0 ? "\n" : "") + "Ethernet " + (NetworkState.networkData?.ethernet?.speed || "");

        if (root.vpnConnected)
            tip += "\nVPN: " + root.vpnName;

        return tip;
    }

    RowLayout {
        id: contentRow

        anchors.centerIn: parent
        spacing: 4

        Text {
            text: {
                if (root.ethernetConnected)
                    return "󰈀"; // ethernet icon

                if (!root.networkConnected)
                    return "󰤭";

                var sig = NetworkState.networkData?.active_signal || 0;
                if (sig > 75) return "󰤨";
                if (sig > 50) return "󰤥";
                if (sig > 25) return "󰤢";
                return "󰤟";
            }
            color: root.networkConnected ? Theme.fg : Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }

        Text {
            text: "" // lock icon
            visible: root.vpnConnected
            color: Theme.green
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }

        Text {
            text: {
                if (!root.networkConnected)
                    return "Disconnected";

                if (root.ethernetConnected)
                    return "Ethernet " + (NetworkState.networkData?.ethernet?.speed || "");

                if (root.networkBand.length > 0)
                    return root.networkSsid + " [" + root.networkBand + "]";

                return root.networkSsid;
            }

            visible: text.length > 0
            color: root.networkConnected ? Qt.alpha(Theme.fg, 0.7) : Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 11
            elide: Text.ElideRight
            Layout.maximumWidth: 120
        }
    }
}
