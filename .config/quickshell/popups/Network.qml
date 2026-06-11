import QtQuick
import Quickshell
import Quickshell.Io
import "../service"

PopupPanel {
    id: root

    // ── PopupPanel Configuration ──
    anchorSide: "right"
    panelWidth: 360
    initialOffset: -360
    finalInset: 32
    introDuration: 120
    exitDuration: 100

    Component.onCompleted: {
        NetworkState.popup = root
    }

    property bool dataLoaded: false
    property int retryCount: 0

    // ── Network State ──
    property bool wifiEnabled:    false
    property bool airplaneMode:   false
    property bool connected:      false
    property string activeSsid:   ""
    property int activeSignal:    0
    property string activeBand:   ""
    property string activeSpeed:  ""
    property bool warpConnected:  false
    property bool warpAvailable:  false
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
    property bool scanTimedOut: false

    // ── Listen to NetworkState changes ──
    Connections {
        target: NetworkState
        function onNetworkDataChanged() {
            var data = NetworkState.networkData
            if (!data) return
            root.dataLoaded    = true
            root.scanTimedOut  = false
            scanTimeoutTimer.stop()
            root.wifiEnabled   = data.wifi_enabled
            root.airplaneMode  = data.airplane_mode
            root.connected     = data.connected
            root.activeSsid    = data.active_ssid  || ""
            root.activeSignal  = data.active_signal || 0
            root.activeBand    = data.active_band || ""
            root.activeSpeed   = data.active_speed || ""
            root.warpConnected = data.warp_connected || false
            root.warpAvailable = data.warp_available || false
            root.details       = data.details  || { ip_address:"", gateway:"", dns:"", subnet:"", security:"", bssid:"" }
            root.networks      = data.networks || []
            root.vpns          = data.vpns     || []
        }
    }

    // ── Scan Timeout ──
    Timer {
        id: scanTimeoutTimer
        interval: 15000
        onTriggered: root.scanTimedOut = true
    }

    // ── Helpers ──
    function showError(msg) {
        root.errorMessage = msg.length > 80 ? msg.substring(0, 80) + "…" : msg
        errorTimer.restart()
    }

    function triggerRefresh() {
        NetworkState.refreshRequested()
    }

    function disconnectWifi() {
        if (!root.activeSsid) return
        root.runAction(["nmcli", "connection", "down", "id", root.activeSsid])
    }

    property string lastConnectSsid: ""

    function connectToNetwork(network) {
        if (!network || network.ssid === root.activeSsid || root.connecting || connectProc.running) return

        root.retryCount = 0
        root.pendingSsid = ""
        root.lastConnectSsid = network.ssid

        root.connecting = true
        connectProc.usePassword = false
        if (network.autoconnect) {
            connectProc.command = ["nmcli", "connection", "up", network.ssid]
        } else {
            connectProc.command = ["nmcli", "dev", "wifi", "connect", network.ssid]
        }
        connectProc.running = true
    }

    function submitPassword(pwd) {
        if (!pwd || pwd.trim() === "" || !root.pendingSsid) return
        root.connecting = true
        connectProc.usePassword = true
        connectProc.command = ["nmcli", "dev", "wifi", "connect", root.pendingSsid, "password", pwd]
        connectProc.running = true
        root.pendingSsid = ""
    }

    function runAction(cmdArray) {
        if (!actionProc.running) {
            actionProc.command = cmdArray
            actionProc.running = true
            return
        }
        if (!fallbackActionProc.running) {
            fallbackActionProc.command = cmdArray
            fallbackActionProc.running = true
            return
        }
        Quickshell.execDetached(cmdArray)
        refreshTimer.start()
    }

    // ── Generic Action Processes ──
    Process {
        id: actionProc
        environment: ({ LANG: "C", LC_ALL: "C" })
        stderr: StdioCollector {}
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                var err = actionProc.stderr.text.trim().replace(/^Error:\s*/i, "")
                if (err.length > 0) root.showError(err)
            }
            root.triggerRefresh()
        }
    }

    Process {
        id: fallbackActionProc
        environment: ({ LANG: "C", LC_ALL: "C" })
        stderr: StdioCollector {}
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                var err = fallbackActionProc.stderr.text.trim().replace(/^Error:\s*/i, "")
                if (err.length > 0) root.showError(err)
            }
            root.triggerRefresh()
        }
    }

    // ── Connection Process ──
    Process {
        id: connectProc
        property bool usePassword: false
        environment: ({ LANG: "C", LC_ALL: "C" })
        stderr: StdioCollector {}
        onExited: function(exitCode) {
            root.connecting = false
            if (exitCode !== 0) {
                var err = connectProc.stderr.text
                if (err.includes("Secrets were required") || err.includes("password")) {
                    if (connectProc.usePassword) {
                        root.showError("Connection failed. Wrong password?")
                    } else {
                        root.pendingSsid = root.lastConnectSsid
                    }
                } else {
                    root.showError("Failed to connect: " + err.trim().substring(0, 60))
                    if (!connectProc.usePassword) {
                        root.retryCount = 0
                        retryConnectTimer.start()
                    }
                }
            }
            root.triggerRefresh()
        }
    }

    Timer {
        id: retryConnectTimer
        interval: 2000
        repeat: false
        onTriggered: {
            if (root.retryCount < 3) {
                root.retryCount++
                connectProc.running = true
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: 2000
        onTriggered: root.triggerRefresh()
    }

    Timer {
        id: errorTimer
        interval: 4000
        repeat: false
        onTriggered: root.errorMessage = ""
    }

    onBeforeClose: {
        root.pendingSsid = ""
        root.detailsExpanded = false
        root.expandedNetworkSsid = ""
        root.errorMessage = ""
        root.scanTimedOut = false
        scanTimeoutTimer.stop()
    }

    onBeforeOpen: {
        root.scanTimedOut = false
        scanTimeoutTimer.restart()
        root.triggerRefresh()
    }

    // ── Content ──
    contentComponent: Component {
        Item {
            anchors.fill: parent
            implicitWidth: mainLayout.implicitWidth
            implicitHeight: mainLayout.implicitHeight
            Column {
                id: mainLayout
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 8

                // ── Section 1: Header ──
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
                    }

                    Column {
                        width: parent.width
                        spacing: 1
                        visible: root.connected

                        Text {
                            text: "SSID: " + root.activeSsid
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }

                        Text {
                            text: "Signal: " + root.activeSignal + "%"
                            color: Theme.fg
                            opacity: 0.6
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }

                        Text {
                            text: root.activeBand
                            color: Theme.fg
                            opacity: 0.6
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            visible: root.activeBand.length > 0
                        }

                        Text {
                            text: root.activeSpeed
                            color: Theme.fg
                            opacity: 0.6
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            visible: root.activeSpeed.length > 0
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.primary
                    opacity: 0.15
                }

                // ── Section 2: Quick Toggles ──
                Row {
                    spacing: 20
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text {
                        text: "Wi-Fi: " + (root.wifiEnabled ? "On" : "Off")
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.bold: true

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
                        font.pixelSize: 12
                        font.bold: true

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

                // ── Section 3: Connection Details ──
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
                            font.pixelSize: 13
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.detailsExpanded = !root.detailsExpanded }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 2
                        clip: true

                        height: (root.detailsExpanded && root.connected) ? implicitHeight : 0
                        opacity: (root.detailsExpanded && root.connected) ? 1 : 0

                        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        Text { text: "  IP: " + root.details.ip_address; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: 11 }
                        Text { text: "  Gateway: " + root.details.gateway; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: 11 }
                        Text { text: "  Subnet: " + root.details.subnet; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: 11 }
                        Text { text: "  DNS: " + root.details.dns; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: 11 }
                        Text { text: "  BSSID: " + root.details.bssid; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: 11 }
                        Text { text: "  Band: " + root.activeBand; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: 11; visible: root.activeBand.length > 0 }
                        Text { text: "  Security: " + root.details.security; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: 11 }
                    }

                    Text {
                        text: "  No connection active"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        visible: root.detailsExpanded && !root.connected
                    }
                }

                // ── Section 4: VPN ──
                Column {
                    width: parent.width
                    spacing: 3

                    Text {
                        text: "VPN"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                    }

                    Rectangle {
                        visible: root.warpAvailable
                        width: parent.width
                        height: 16
                        color: "transparent"

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "WARP: " + (root.warpConnected ? "Connected" : "Disconnected")
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.warpConnected ? "disconnect" : "connect"
                            color: Theme.primary
                            font.family: Theme.fontFamily
                            font.pixelSize: 11

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
                                    font.pixelSize: 11
                                }

                                Text {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.active ? "disconnect" : "connect"
                                    color: Theme.primary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.runAction(modelData.active
                                                ? ["nmcli", "connection", "down", modelData.name]
                                                : ["nmcli", "connection", "up", modelData.name])
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
                        font.pixelSize: 11
                        visible: root.vpns.length === 0 && !(root.warpAvailable && root.warpConnected)
                    }
                }

                // ── Section 5: Scanned Network List ──
                Column {
                    width: parent.width
                    spacing: 3

                    Text {
                        text: "WiFi Networks"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                    }

                    Text {
                        visible: !root.dataLoaded
                        text: root.scanTimedOut ? "Timed out — close & reopen" : "Scanning…"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }

                    Text {
                        visible: root.dataLoaded && root.networks.length === 0 && root.wifiEnabled
                        text: "No networks found"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }

                    Text {
                        visible: root.dataLoaded && !root.wifiEnabled
                        text: "Wi-Fi is off"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }

                    ListView {
                        width: parent.width
                        height: Math.min(contentHeight, 300)
                        model: root.networks
                        interactive: true
                        clip: true

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
                                        font.pixelSize: 11
                                        font.bold: modelData.active
                                        elide: Text.ElideRight
                                        width: 240
                                    }
                                }

                                Text {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    textFormat: Text.RichText
                                    text: {
                                        var bars = Math.round(modelData.signal / 20)
                                        var on  = Theme.fg, off = Qt.alpha(Theme.fg, 0.2), s = ""
                                        for (var i = 0; i < 5; i++)
                                            s += "<font color='" + (i < bars ? on : off) + "'>█</font>"
                                        return s
                                    }
                                }

                                MouseArea {
                                    id: ssidMa
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.expandedNetworkSsid = (root.expandedNetworkSsid === modelData.ssid) ? "" : modelData.ssid
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
                                        font.pixelSize: 11

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (modelData.active)
                                                    root.runAction(["nmcli", "connection", "down", "id", modelData.ssid])
                                                else
                                                    root.connectToNetwork(modelData)
                                                root.expandedNetworkSsid = ""
                                            }
                                        }
                                    }

                                    Text {
                                        text: "Forget"
                                        color: Theme.error
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.runAction(["nmcli", "connection", "delete", "id", modelData.ssid])
                                                root.expandedNetworkSsid = ""
                                            }
                                        }
                                    }

                                    Text {
                                        text: "Auto: " + (modelData.autoconnect ? "On" : "Off")
                                        color: Theme.fg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var val = modelData.autoconnect ? "no" : "yes"
                                                root.runAction(["nmcli", "connection", "modify", modelData.ssid, "connection.autoconnect", val])
                                                root.expandedNetworkSsid = ""
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
                                }
                            }
                        }
                    }
                }

                // ── Section 6: Footer Actions ──
                Row {
                    spacing: 20
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text {
                        text: "Settings"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 11

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Quickshell.execDetached(Config.impalaCmd)
                                root.closePopup()
                            }
                        }
                    }

                    Text {
                        text: "Restart Wi-Fi"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 11

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.runAction(["sh", "-c", "nmcli radio wifi off && sleep 0.5 && nmcli radio wifi on"])
                            }
                        }
                    }
                }
            }

            // ── Error Toast ──
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: Math.max(28, errText.implicitHeight + 10)
                color: Theme.error
                radius: 6
                visible: opacity > 0
                opacity: root.errorMessage !== "" ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                Text {
                    id: errText
                    anchors.centerIn: parent
                    text: root.errorMessage
                    color: Theme.bg
                    font.pixelSize: 13
                    font.bold: true
                }
                MouseArea { anchors.fill: parent; onClicked: root.errorMessage = "" }
            }

            // ── Inline Password Dialog ──
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
                            font.pixelSize: 11
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
                                font.pixelSize: 11
                                echoMode: TextInput.Password
                                focus: root.pendingSsid !== ""
                                onVisibleChanged: if (visible) forceActiveFocus()
                                onAccepted: { root.submitPassword(text); text = ""; }
                                Keys.onEscapePressed: { root.pendingSsid = ""; text = ""; }
                            }
                        }

                        Row {
                            spacing: 8
                            anchors.right: parent.right

                            Text {
                                text: "Cancel"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
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
                                    font.pixelSize: 11
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
