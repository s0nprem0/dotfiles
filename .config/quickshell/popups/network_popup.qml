import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Ipc
import ".."

Scope {
    id: root

    property bool showPopup: false
    property bool dataLoaded: false
    property int retryCount: 0

    // ── Network State ──────────────────────────────────────────────────────────
    property bool wifiEnabled:    false
    property bool airplaneMode:   false
    property bool connected:      false
    property string activeSsid:   ""
    property int activeSignal:    0
    property bool warpConnected:  false
    property var details: ({
        "ip_address": "", "gateway": "", "dns": "",
        "subnet": "", "security": "", "bssid": ""
    })
    property var networks: []
    property var vpns: []
    property bool detailsExpanded: false
    property string expandedNetworkSsid: ""

    property string pendingSsid: ""
    property bool connecting: false
    property string errorMessage: ""
    property var networkData: NetworkState.networkData

    signal requestClose()

    // ── IPC ───────────────────────────────────────────────────────────────────
    IpcHandler {
        target: "network_popup"
        function toggle() { root.requestClose(); }
    }

    // ── Theme (imported from Theme.js) ──────────────────────────────────────────

    // ── Helpers ───────────────────────────────────────────────────────────────

    function showError(msg) {
        root.errorMessage = msg.length > 80 ? msg.substring(0, 80) + "…" : msg;
        errorTimer.restart();
    }

    function triggerRefresh() {
        if (NetworkState.refreshNetworkData) NetworkState.refreshNetworkData();
    }

    function disconnectWifi() {
        if (!root.activeSsid) return;
        root.runAction(["nmcli", "connection", "down", "id", root.activeSsid]);
    }

    function connectToNetwork(ssid) {
        if (ssid === root.activeSsid || root.connecting || connectProc.running) return;
        root.connecting = true;
        root.retryCount = 0;
        root.pendingSsid = "";
        connectProc.usePassword = false;
        connectProc.command = ["nmcli", "dev", "wifi", "connect", ssid];
        connectProc.running = true;
    }

    function submitPassword(pwd) {
        if (!pwd || pwd.trim() === "" || !root.pendingSsid) return;
        root.connecting = true;
        connectProc.usePassword = true;
        connectProc.command = [
            "nmcli", "dev", "wifi", "connect", root.pendingSsid,
            "password", pwd
        ];
        connectProc.running = true;
        root.pendingSsid = "";
    }

    function runAction(cmdArray) {
        if (actionProc.running) {
            Quickshell.execDetached(cmdArray);
            root.triggerRefresh();
            return;
        }
        actionProc.command = cmdArray;
        actionProc.running = true;
    }

    // ── Network Data (shared from NetModule via NetworkState) ─────────────────
    onNetworkDataChanged: {
        var data = NetworkState.networkData;
        if (!data) return;
        root.dataLoaded    = true;
        root.wifiEnabled   = data.wifi_enabled;
        root.airplaneMode  = data.airplane_mode;
        root.connected     = data.connected;
        root.activeSsid    = data.active_ssid  || "";
        root.activeSignal  = data.active_signal || 0;
        root.warpConnected = data.warp_connected || false;
        root.details       = data.details  || { ip_address:"", gateway:"", dns:"", subnet:"", security:"", bssid:"" };
        root.networks      = data.networks || [];
        root.vpns          = data.vpns     || [];
    }

    // ── Generic Action Process (captures stderr, shows errors) ────────────────
    Process {
        id: actionProc
        environment: ({ LANG: "C", LC_ALL: "C" })
        stderr: StdioCollector {}
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                var err = actionProc.stderr.text.trim().replace(/^Error:\s*/i, "");
                if (err.length > 0) root.showError(err);
            }
            root.triggerRefresh();
        }
    }

    // ── Connection Process (handles password prompts & retry) ─────────────────
    Process {
        id: connectProc
        property bool usePassword: false
        environment: ({ LANG: "C", LC_ALL: "C" })
        stderr: StdioCollector {}
        onExited: function(exitCode) {
            root.connecting = false;
            if (exitCode !== 0) {
                var err = connectProc.stderr.text;
                if (err.includes("Secrets were required") || err.includes("password")) {
                    if (connectProc.usePassword) {
                        root.showError("Connection failed. Wrong password?");
                    } else {
                        root.pendingSsid = connectProc.command[4];
                    }
                } else {
                    root.showError("Failed to connect: " + err.trim().substring(0, 60));
                    if (!connectProc.usePassword) {
                        root.retryCount = 0;
                        retryConnectTimer.start();
                    }
                }
            }
            root.triggerRefresh();
        }
    }

    Timer {
        id: retryConnectTimer
        interval: 2000
        repeat: false
        onTriggered: {
            if (root.retryCount < 3) {
                root.retryCount++;
                connectProc.running = true;
            }
        }
    }

    Timer {
        id: errorTimer
        interval: 4000
        repeat: false
        onTriggered: root.errorMessage = ""
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Per-screen windows via Variants
    // ══════════════════════════════════════════════════════════════════════════
    Variants {
        model: Quickshell.screens
        delegate: Component {
            PanelWindow {
                id: win
                required property var modelData
                visible: false

                property bool isClosing: false
                property real animRightMargin: -260
                property real animOpacity: 0
                property bool showPopup: root.showPopup

                onShowPopupChanged: {
                    if (root.showPopup) {
                        exitAnim.stop();
                        isClosing = false;
                        animRightMargin = -260;
                        animOpacity = 0;
                        root.triggerRefresh();
                        win.visible = true;
                        introAnim.start();
                    } else if (!isClosing) {
                        introAnim.stop();
                        closePopup();
                    }
                }

                function closePopup() {
                    if (isClosing) return;
                    isClosing = true;
                    root.pendingSsid = "";
                    root.detailsExpanded = false;
                    root.expandedNetworkSsid = "";
                    root.errorMessage = "";
                    exitAnim.start();
                }

                screen: modelData
                color: "transparent"
                exclusionMode: PanelWindow.ExclusionMode.Ignore
                focusable: true
                implicitWidth: 360
                implicitHeight: mainLayout.implicitHeight + 20

                Component.onCompleted: { root.triggerRefresh(); }

                Connections {
                    target: root
                    function onRequestClose() { win.closePopup(); }
                }

                anchors {
                    top: true
                    right: true
                }

                margins {
                    top: (root.parent && root.parent.implicitHeight ? root.parent.implicitHeight : 36) + 4
                    right: win.animRightMargin
                }

                // Slide-in + fade-in
                ParallelAnimation {
                    id: introAnim
                    NumberAnimation { target: win; property: "animRightMargin"; from: -260; to: 32; duration: 120; easing.type: Easing.OutCubic }
                    NumberAnimation { target: win; property: "animOpacity"; from: 0; to: 1; duration: 120; easing.type: Easing.OutCubic }
                }

                // Slide-out + fade-out
                ParallelAnimation {
                    id: exitAnim
                    onStopped: {
                        win.visible = false;
                        root.showPopup = false;
                    }
                    NumberAnimation { target: win; property: "animRightMargin"; from: 32; to: -260; duration: 100; easing.type: Easing.InCubic }
                    NumberAnimation { target: win; property: "animOpacity"; from: 1; to: 0; duration: 100; easing.type: Easing.InCubic }
                }

                HyprlandFocusGrab {
                    active: !win.isClosing
                    windows: [win]
                    onCleared: { win.closePopup(); }
                }

                Rectangle {
                    anchors.fill: parent
                    opacity: win.animOpacity
                    color: Theme.bg
                    border.width: 1
                    border.color: Theme.primary
                    radius: 0
                    focus: true
                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) win.closePopup();
                    }
                    Component.onCompleted: { forceActiveFocus(); }

                    Column {
                        id: mainLayout
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 10
                        spacing: 8

                        // ── Section 1: Header ──────────────────────────────────
                        Column {
                            width: parent.width
                            spacing: 2

                            Text {
                                text: root.connecting
                                    ? "Connecting…"
                                    : (root.connected ? "Wi-Fi Connected" : "Wi-Fi Disconnected")
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.bold: true
                                renderType: Text.NativeRendering
                            }

                            Column {
                                width: parent.width
                                spacing: 1
                                visible: root.connected

                                Text {
                                    text: "SSID: " + root.activeSsid
                                    color: Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 14
                                    elide: Text.ElideRight
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    text: "Signal: " + root.activeSignal + "%"
                                    color: Theme.fg
                                    opacity: 0.6
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 14
                                    renderType: Text.NativeRendering
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.primary
                            opacity: 0.15
                        }

                        // ── Section 2: Quick Toggles ───────────────────────────
                        Row {
                            spacing: 20
                            anchors.horizontalCenter: parent.horizontalCenter

                            Text {
                                text: "Wi-Fi: " + (root.wifiEnabled ? "On" : "Off")
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.bold: true
                                renderType: Text.NativeRendering

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.runAction(["nmcli", "radio", "wifi", root.wifiEnabled ? "off" : "on"])
                                }
                            }

                            Text {
                                text: "Airplane: " + (root.airplaneMode ? "On" : "Off")
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.bold: true
                                renderType: Text.NativeRendering

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.runAction(["rfkill", root.airplaneMode ? "unblock" : "block", "all"])
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.primary
                            opacity: 0.15
                        }

                        // ── Section 3: Connection Details ──────────────────────
                        Column {
                            width: parent.width
                            spacing: 4

                            Rectangle {
                                width: parent.width
                                height: 14
                                color: "transparent"

                                Text {
                                    text: "Details " + (root.detailsExpanded ? "▲" : "▼")
                                    color: Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 14
                                    font.bold: true
                                    renderType: Text.NativeRendering
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { root.detailsExpanded = !root.detailsExpanded; }
                                }
                            }

                            Column {
                                width: parent.width
                                spacing: 2
                                visible: root.detailsExpanded && root.connected

                                Text { text: "  IP: " + root.details.ip_address; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: 14; renderType: Text.NativeRendering }
                                Text { text: "  Gateway: " + root.details.gateway; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: 14; renderType: Text.NativeRendering }
                                Text { text: "  Subnet: " + root.details.subnet; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: 14; renderType: Text.NativeRendering }
                                Text { text: "  DNS: " + root.details.dns; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: 14; renderType: Text.NativeRendering }
                                Text { text: "  BSSID: " + root.details.bssid; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: 14; renderType: Text.NativeRendering }
                                Text { text: "  Security: " + root.details.security; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: 14; renderType: Text.NativeRendering }
                            }

                            Text {
                                text: "  No connection active"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                renderType: Text.NativeRendering
                                visible: root.detailsExpanded && !root.connected
                            }
                        }

                        // ── Section 4: VPN ─────────────────────────────────────
                        Column {
                            width: parent.width
                            spacing: 3

                            Text {
                                text: "VPN"
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.bold: true
                                renderType: Text.NativeRendering
                            }

                            Rectangle {
                                width: parent.width
                                height: 16
                                color: "transparent"

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "WARP: " + (root.warpConnected ? "Connected" : "Disconnected")
                                    color: Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 14
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.warpConnected ? "disconnect" : "connect"
                                    color: Theme.primary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 14
                                    renderType: Text.NativeRendering

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.runAction(root.warpConnected ? ["warp-cli", "disconnect"] : ["warp-cli", "connect"])
                                    }
                                }
                            }

                            Column {
                                width: parent.width
                                spacing: 2
                                visible: root.vpns.length > 0

                                Repeater {
                                    model: root.vpns
                                    delegate: Rectangle {
                                        width: parent.width
                                        height: 16
                                        color: "transparent"

                                        Text {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.name + " (" + modelData.vpn_type + ")"
                                            color: Theme.fg
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 14
                                            renderType: Text.NativeRendering
                                        }

                                        Text {
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.active ? "disconnect" : "connect"
                                            color: Theme.primary
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 14
                                            renderType: Text.NativeRendering

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.runAction(modelData.active
                                                        ? ["nmcli", "connection", "down", modelData.name]
                                                        : ["nmcli", "connection", "up", modelData.name]);
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                text: "  Disabled"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                renderType: Text.NativeRendering
                                visible: root.vpns.length === 0 && !root.warpConnected
                            }
                        }

                        // ── Section 5: Scanned Network List ────────────────────
                        Column {
                            width: parent.width
                            spacing: 3

                            Text {
                                text: "WiFi Networks"
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.bold: true
                                renderType: Text.NativeRendering
                            }

                            Text {
                                visible: !root.dataLoaded || (root.networks.length === 0 && checkStatusProc.running)
                                text: "Scanning…"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                renderType: Text.NativeRendering
                            }

                            Text {
                                visible: root.dataLoaded && root.networks.length === 0 && !checkStatusProc.running && root.wifiEnabled
                                text: "No networks found"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                renderType: Text.NativeRendering
                            }

                            Text {
                                visible: root.dataLoaded && !root.wifiEnabled
                                text: "Wi-Fi is off"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                renderType: Text.NativeRendering
                            }

                            Column {
                                width: parent.width
                                spacing: 3

                                Repeater {
                                    model: root.networks

                                    delegate: Column {
                                        width: parent.width
                                        spacing: 2

                                        Rectangle {
                                            width: parent.width
                                            height: 16
                                            color: "transparent"

                                            Row {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 4

                                                Text {
                                                    text: (modelData.active ? "* " : "  ") + modelData.ssid
                                                    color: Theme.fg
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 14
                                                    font.bold: modelData.active
                                                    elide: Text.ElideRight
                                                    width: 240
                                                    renderType: Text.NativeRendering
                                                }
                                            }

                                            Text {
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                textFormat: Text.RichText
                                                text: {
                                                    var bars = Math.round(modelData.signal / 20);
                                                    var on  = "#f1dfdb", off = "#271d1c", s = "";
                                                    for (var i = 0; i < 5; i++)
                                                        s += "<font color='" + (i < bars ? on : off) + "'>█</font>";
                                                    return s;
                                                }
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 14
                                                renderType: Text.NativeRendering
                                            }

                                            MouseArea {
                                                id: ssidMa
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                property bool dblClicked: false
                                                onClicked: {
                                                    dblClicked = false;
                                                    clickTimer.start();
                                                }
                                                onDoubleClicked: {
                                                    dblClicked = true;
                                                    clickTimer.stop();
                                                    root.connectToNetwork(modelData.ssid);
                                                }
                                            }

                                            Timer {
                                                id: clickTimer
                                                interval: 250
                                                repeat: false
                                                onTriggered: {
                                                    if (ssidMa.dblClicked) return;
                                                    root.expandedNetworkSsid =
                                                        (root.expandedNetworkSsid === modelData.ssid)
                                                            ? "" : modelData.ssid;
                                                }
                                            }
                                        }

                                        Column {
                                            width: parent.width
                                            spacing: 2
                                            visible: root.expandedNetworkSsid === modelData.ssid

                                            Row {
                                                spacing: 10
                                                anchors.horizontalCenter: parent.horizontalCenter

                                                Text {
                                                    text: modelData.active ? "Disconnect" : "Connect"
                                                    color: Theme.primary
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 14
                                                    renderType: Text.NativeRendering

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            if (modelData.active)
                                                                root.runAction(["nmcli", "connection", "down", "id", modelData.ssid]);
                                                            else
                                                                root.connectToNetwork(modelData.ssid);
                                                            root.expandedNetworkSsid = "";
                                                        }
                                                    }
                                                }

                                                Text {
                                                    text: "Forget"
                                                    color: Theme.error
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 14
                                                    renderType: Text.NativeRendering

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            root.runAction(["nmcli", "connection", "delete", modelData.ssid]);
                                                            root.expandedNetworkSsid = "";
                                                        }
                                                    }
                                                }

                                                Text {
                                                    text: "Auto: " + (modelData.autoconnect ? "On" : "Off")
                                                    color: Theme.fg
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 14
                                                    renderType: Text.NativeRendering

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            var val = modelData.autoconnect ? "no" : "yes";
                                                            root.runAction(["nmcli", "connection", "modify", modelData.ssid, "connection.autoconnect", val]);
                                                            root.expandedNetworkSsid = "";
                                                        }
                                                    }
                                                }
                                            }

                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: "Security: " + modelData.security + " | Rate: " + modelData.rate
                                                color: Theme.muted
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 13
                                                renderType: Text.NativeRendering
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ── Section 6: Footer Actions ──────────────────────────
                        Row {
                            spacing: 20
                            anchors.horizontalCenter: parent.horizontalCenter

                            Text {
                                text: "Settings"
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                renderType: Text.NativeRendering

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Quickshell.execDetached(["hyprctl", "dispatch", "exec", "[float;size 55% 65%;center] ghostty --title=impala -e impala"]);
                                        win.closePopup();
                                    }
                                }
                            }

                            Text {
                                text: "Restart Wi-Fi"
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                renderType: Text.NativeRendering

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Quickshell.execDetached(["nmcli", "radio", "wifi", "off"]);
                                        Quickshell.execDetached(["sh", "-c", "sleep 0.5 && nmcli radio wifi on"]);
                                        root.triggerRefresh();
                                    }
                                }
                            }
                        }
                    }

                    // ── Error Toast ────────────────────────────────────────────
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - 20
                        height: Math.max(28, errText.implicitHeight + 10)
                        color: Theme.error
                        radius: 6
                        opacity: root.errorMessage !== "" ? 1 : 0
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                        Text {
                            id: errText
                            anchors.centerIn: parent
                            text: root.errorMessage
                            color: Theme.bg
                            font.pixelSize: 13
                            font.bold: true
                            renderType: Text.NativeRendering
                        }
                        MouseArea { anchors.fill: parent; onClicked: root.errorMessage = "" }
                    }

                    // ── Inline Password Dialog ─────────────────────────────────
                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(0.1, 0.06, 0.06, 0.88)
                        visible: root.pendingSsid !== ""

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width - 24; height: 148
                            radius: 8; color: Theme.surface
                            border.color: Theme.primary; border.width: 1

                            Column {
                                anchors.fill: parent; anchors.margins: 14; spacing: 10

                                Text {
                                    text: "Password for " + root.pendingSsid
                                    color: Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 14
                                    font.bold: true
                                    elide: Text.ElideRight
                                    width: parent.width
                                }

                                Rectangle {
                                    width: parent.width; height: 34
                                    color: Theme.bg
                                    radius: 5
                                    border.color: pwdInput.activeFocus ? Theme.primary : Theme.surface
                                    border.width: 1

                                    TextInput {
                                        id: pwdInput
                                        anchors.fill: parent; anchors.margins: 8
                                        color: Theme.fg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 14
                                        echoMode: TextInput.Password
                                        focus: root.pendingSsid !== ""
                                        onVisibleChanged: if (visible) forceActiveFocus()
                                        onAccepted: { root.submitPassword(text); text = ""; }
                                        Keys.onEscapePressed: { root.pendingSsid = ""; text = ""; }
                                    }
                                }

                                Row {
                                    spacing: 14
                                    anchors.right: parent.right

                                    Text {
                                        text: "Cancel"
                                        color: Theme.muted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 14
                                        anchors.verticalCenter: parent.verticalCenter

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: { root.pendingSsid = ""; pwdInput.text = ""; }
                                        }
                                    }

                                    Rectangle {
                                        width: 64; height: 28
                                        radius: 5; color: Theme.blue
                                        Text {
                                            anchors.centerIn: parent
                                            text: "Connect"
                                            color: Theme.bg
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 14
                                            font.bold: true
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: { root.submitPassword(pwdInput.text); pwdInput.text = ""; }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
