import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import ".."
import "../components"

BarModule {
    id: root

    implicitWidth: contentRow.implicitWidth + 24

    property bool networkConnected: false
    property string networkSsid: ""
    property string networkBand: ""

    DataModule {
        id: netData
        path: Theme.bin("get_network_status")
        interval: 10000

        onDataReceived: function(j) {
            root.networkConnected = j.connected || false;
            root.networkSsid = j.active_ssid || "";
            root.networkBand = j.active_band || "";
            NetworkState.networkData = j;
        }
    }

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

        return root.networkBand.length > 0
            ? root.networkSsid + " (" + root.networkBand + ")"
            : root.networkSsid;
    }

    RowLayout {
        id: contentRow

        anchors.centerIn: parent
        spacing: 4

        Text {
            text: root.networkConnected ? "󰤨" : "󰤭"
            color: root.networkConnected ? Theme.fg : Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }

        Text {
            text: {
                if (!root.networkConnected)
                    return "Disconnected";

                if (root.networkBand.length > 0)
                    return root.networkSsid + " [" + root.networkBand + "]";

                return root.networkSsid;
            }

            visible: text.length > 0
            color: root.networkConnected ? Qt.alpha(Theme.fg, 0.7) : Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 11
            elide: Text.ElideRight
        }
    }
}
