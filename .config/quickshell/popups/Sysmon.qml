import "../service"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

PopupPanel {
    id: root

    property var sysData: ({})
    property bool loading: false
    property string errorMsg: ""

    // Sparkline history (up to 30 samples)
    property var cpuHistory: []
    property var memHistory: []
    property var diskHistory: []
    property var rxHistory: []
    property var txHistory: []
    property int maxSamples: 30

    function refresh() {
        root.loading = true;
        root.errorMsg = "";
        sysProc.running = true;
    }

    function formatBytes(bytes) {
        if (bytes >= 1_000_000) return (bytes / 1_000_000).toFixed(1) + " MB/s";
        if (bytes >= 1_000) return (bytes / 1_000).toFixed(1) + " KB/s";
        return bytes.toFixed(0) + " B/s";
    }

    function pushSample(arr, val) {
        arr.push(val);
        if (arr.length > root.maxSamples) arr.shift();
    }

    function sparklinePath(history, width, height) {
        if (history.length < 2) return "";
        var maxVal = 1;
        for (var i = 0; i < history.length; i++) {
            if (history[i] > maxVal) maxVal = history[i];
        }
        var path = "";
        var stepX = width / (root.maxSamples - 1);
        for (var i = 0; i < history.length; i++) {
            var x = i * stepX;
            var y = height - (history[i] / maxVal * height);
            path += (i === 0 ? "M" : "L") + x.toFixed(1) + " " + y.toFixed(1);
        }
        return path;
    }

    function sparklineNetPath(history, width, height, offset) {
        if (history.length < 2) return "";
        var maxVal = 1;
        for (var i = 0; i < history.length; i++) {
            if (history[i] > maxVal) maxVal = history[i];
        }
        var path = "";
        var stepX = width / (root.maxSamples - 1);
        for (var i = 0; i < history.length; i++) {
            var x = i * stepX;
            var y = offset + history[i] / maxVal * height;
            path += (i === 0 ? "M" : "L") + x.toFixed(1) + " " + y.toFixed(1);
        }
        return path;
    }

    anchorSide: "right"
    panelWidth: 360
    initialOffset: -360
    finalInset: 32
    introDuration: 120
    exitDuration: 100

    onBeforeOpen: {
        root.refresh();
        pollTimer.start();
    }

    onBeforeClose: {
        pollTimer.stop();
        root.errorMsg = "";
    }

    Process {
        id: sysProc

        command: [Theme.bin("get_sysmon_status")]
        environment: ({ "LANG": "C", "LC_ALL": "C" })

        onExited: function(code) {
            root.loading = false;
            if (code !== 0)
                root.errorMsg = "sysmon exited with code " + code;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                var text = this.text.trim();
                if (!text) {
                    root.loading = false;
                    return;
                }
                try {
                    var data = JSON.parse(text);
                    root.sysData = data;
                    root.pushSample(root.cpuHistory, data.cpu_usage || 0);
                    root.pushSample(root.memHistory, data.memory_percent || 0);
                    root.pushSample(root.diskHistory, data.disk_percent || 0);
                    root.pushSample(root.rxHistory, data.net_rx_bytes_sec || 0);
                    root.pushSample(root.txHistory, data.net_tx_bytes_sec || 0);
                } catch (e) {
                    root.errorMsg = "Parse error";
                    root.loading = false;
                }
            }
        }

        stderr: StdioCollector {}
    }

    Timer {
        id: pollTimer

        interval: 2000
        repeat: true
        onTriggered: {
            if (!sysProc.running)
                sysProc.running = true;
        }
    }

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

                // Header
                Text {
                    text: "System Monitor"
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize2xl
                    font.bold: true
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.primary
                    opacity: 0.15
                }

                // Loading
                Text {
                    visible: root.loading
                    text: "Loading…"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLg
                }

                // Error
                Text {
                    visible: root.errorMsg !== ""
                    text: root.errorMsg
                    color: Theme.error
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLg
                }

                // ── CPU Section ──
                Column {
                    width: parent.width
                    spacing: 2
                    visible: !root.loading && root.errorMsg === ""

                    Text {
                        text: "CPU: " + (root.sysData.cpu_usage ?? "—") + "%"
                            + (root.sysData.cpu_temp ? "  (" + root.sysData.cpu_temp + "°C)" : "")
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLg
                        font.bold: true
                    }

                    Rectangle {
                        width: parent.width
                        height: 8
                        radius: 4
                        color: Theme.surface

                        Rectangle {
                            width: parent.width * Math.min((root.sysData.cpu_usage ?? 0) / 100, 1)
                            height: parent.height
                            radius: 4
                            color: root.sysData.cpu_usage > 80 ? Theme.error : Theme.primary

                            Behavior on width {
                                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    // CPU sparkline
                    Canvas {
                        width: parent.width
                        height: 32
                        visible: root.cpuHistory.length >= 2

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            var path = root.sparklinePath(root.cpuHistory, width, height);
                            if (!path) return;
                            ctx.strokeStyle = Theme.primary;
                            ctx.lineWidth = 2;
                            ctx.beginPath();
                            var cmds = path.split(/(?=[ML])/);
                            for (var i = 0; i < cmds.length; i++) {
                                var parts = cmds[i].trim().split(" ");
                                if (parts[0] === "M") ctx.moveTo(parseFloat(parts[1]), parseFloat(parts[2]));
                                else if (parts[0] === "L") ctx.lineTo(parseFloat(parts[1]), parseFloat(parts[2]));
                            }
                            ctx.stroke();
                        }

                        Connections {
                            target: root
                            function onCpuHistoryChanged() { canvas.requestPaint(); }
                        }
                    }
                }

                // ── Memory Section ──
                Column {
                    width: parent.width
                    spacing: 2
                    visible: !root.loading && root.errorMsg === ""

                    Text {
                        text: "RAM: " + (root.sysData.memory_used_gb ?? "—") + " / "
                            + (root.sysData.memory_total_gb ?? "—") + " GB"
                            + " (" + (root.sysData.memory_percent ?? "—") + "%)"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLg
                        font.bold: true
                    }

                    Rectangle {
                        width: parent.width
                        height: 8
                        radius: 4
                        color: Theme.surface

                        Rectangle {
                            width: parent.width * Math.min((root.sysData.memory_percent ?? 0) / 100, 1)
                            height: parent.height
                            radius: 4
                            color: root.sysData.memory_percent > 80 ? Theme.error : Theme.green

                            Behavior on width {
                                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    Canvas {
                        id: memCanvas

                        width: parent.width
                        height: 32
                        visible: root.memHistory.length >= 2

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            var path = root.sparklinePath(root.memHistory, width, height);
                            if (!path) return;
                            ctx.strokeStyle = Theme.green;
                            ctx.lineWidth = 2;
                            ctx.beginPath();
                            var cmds = path.split(/(?=[ML])/);
                            for (var i = 0; i < cmds.length; i++) {
                                var parts = cmds[i].trim().split(" ");
                                if (parts[0] === "M") ctx.moveTo(parseFloat(parts[1]), parseFloat(parts[2]));
                                else if (parts[0] === "L") ctx.lineTo(parseFloat(parts[1]), parseFloat(parts[2]));
                            }
                            ctx.stroke();
                        }

                        Connections {
                            target: root
                            function onMemHistoryChanged() { memCanvas.requestPaint(); }
                        }
                    }
                }

                // ── Disk Section ──
                Column {
                    width: parent.width
                    spacing: 2
                    visible: !root.loading && root.errorMsg === ""

                    Text {
                        text: "Disk: " + (root.sysData.disk_used_gb ?? "—") + " / "
                            + (root.sysData.disk_total_gb ?? "—") + " GB"
                            + " (" + (root.sysData.disk_percent ?? "—") + "%)"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLg
                        font.bold: true
                    }

                    Rectangle {
                        width: parent.width
                        height: 8
                        radius: 4
                        color: Theme.surface

                        Rectangle {
                            width: parent.width * Math.min((root.sysData.disk_percent ?? 0) / 100, 1)
                            height: parent.height
                            radius: 4
                            color: root.sysData.disk_percent > 85 ? Theme.error : Theme.blue

                            Behavior on width {
                                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    Canvas {
                        id: diskCanvas

                        width: parent.width
                        height: 32
                        visible: root.diskHistory.length >= 2

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            var path = root.sparklinePath(root.diskHistory, width, height);
                            if (!path) return;
                            ctx.strokeStyle = Theme.blue;
                            ctx.lineWidth = 2;
                            ctx.beginPath();
                            var cmds = path.split(/(?=[ML])/);
                            for (var i = 0; i < cmds.length; i++) {
                                var parts = cmds[i].trim().split(" ");
                                if (parts[0] === "M") ctx.moveTo(parseFloat(parts[1]), parseFloat(parts[2]));
                                else if (parts[0] === "L") ctx.lineTo(parseFloat(parts[1]), parseFloat(parts[2]));
                            }
                            ctx.stroke();
                        }

                        Connections {
                            target: root
                            function onDiskHistoryChanged() { diskCanvas.requestPaint(); }
                        }
                    }
                }

                // ── Network Section ──
                Column {
                    width: parent.width
                    spacing: 2
                    visible: !root.loading && root.errorMsg === ""

                    Text {
                        text: "Network"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLg
                        font.bold: true
                    }

                    Row {
                        width: parent.width
                        spacing: 8

                        Text {
                            text: "↓ " + root.formatBytes(root.sysData.net_rx_bytes_sec || 0)
                            color: Theme.green
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                        }

                        Text {
                            text: "↑ " + root.formatBytes(root.sysData.net_tx_bytes_sec || 0)
                            color: Theme.blue
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                        }
                    }

                    Canvas {
                        id: netCanvas

                        width: parent.width
                        height: 40
                        visible: root.rxHistory.length >= 2 || root.txHistory.length >= 2

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);

                            var mid = height / 2;
                            var rxPath = root.sparklineNetPath(root.rxHistory, width, mid, mid);
                            if (rxPath) {
                                ctx.strokeStyle = Theme.green;
                                ctx.lineWidth = 2;
                                ctx.beginPath();
                                var cmds = rxPath.split(/(?=[ML])/);
                                for (var i = 0; i < cmds.length; i++) {
                                    var parts = cmds[i].trim().split(" ");
                                    if (parts[0] === "M") ctx.moveTo(parseFloat(parts[1]), parseFloat(parts[2]));
                                    else if (parts[0] === "L") ctx.lineTo(parseFloat(parts[1]), parseFloat(parts[2]));
                                }
                                ctx.stroke();
                            }

                            // Mirror TX below
                            var txPath = root.sparklineNetPath(root.txHistory, width, mid, 0);
                            if (txPath) {
                                ctx.strokeStyle = Theme.blue;
                                ctx.lineWidth = 2;
                                ctx.beginPath();
                                var cmds = txPath.split(/(?=[ML])/);
                                for (var i = 0; i < cmds.length; i++) {
                                    var parts = cmds[i].trim().split(" ");
                                    if (parts[0] === "M") ctx.moveTo(parseFloat(parts[1]), parseFloat(parts[2]));
                                    else if (parts[0] === "L") ctx.lineTo(parseFloat(parts[1]), parseFloat(parts[2]));
                                }
                                ctx.stroke();
                            }
                        }

                        Connections {
                            target: root
                            function onRxHistoryChanged() { netCanvas.requestPaint(); }
                            function onTxHistoryChanged() { netCanvas.requestPaint(); }
                        }
                    }
                }

                // ── Footer ──
                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.primary
                    opacity: 0.15
                }

                Row {
                    spacing: 12
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text {
                        text: "Refresh"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLg

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.refresh()
                        }
                    }

                    Text {
                        text: "Close"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLg

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closePopup()
                        }
                    }
                }
            }
        }
    }
}
