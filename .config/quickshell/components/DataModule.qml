import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string path: ""
    property var args: []
    property int interval: 5000
    property bool hasError: false
    property bool loading: false
    property int backoffMs: 1000
    property int processTimeoutMs: 15000

    signal dataReceived(var json)

    function refresh() {
        proc.running = true;
        if (!pollTimer.running)
            pollTimer.start();

    }

    visible: false
    onDataReceived: {
        root.backoffMs = 1000;

    }
    Component.onCompleted: {
        startTimer.interval = 1000 + Math.random() * 2000;
        startTimer.restart();
    }

    Process {
        id: proc

        command: [root.path].concat(root.args)
        onRunningChanged: {
            if (proc.running) {
                root.loading = true;
                root.hasError = false;
                root.backoffMs = 1000;
                killTimer.restart();
            } else {
                killTimer.stop();
            }
        }
        onExited: function(code) {
            root.loading = false;
            killTimer.stop();
            if (code !== 0) {
                root.hasError = true;
                crashRestart.interval = root.backoffMs;
                crashRestart.restart();
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                var text = this.text.trim();
                if (!text) {
                    console.warn("DataModule: empty output from", root.path);
                    root.hasError = true;
                    crashRestart.interval = root.backoffMs;
                    crashRestart.restart();
                    return ;
                }
                try {
                    root.dataReceived(JSON.parse(text));
                } catch (e) {
                    root.hasError = true;
                    crashRestart.interval = root.backoffMs;
                    crashRestart.restart();
                    console.warn("DataModule JSON parse error:", e, "path:", root.path, "data:", text.substring(0, 200));
                }
            }
        }

    }

    Timer {
        id: killTimer

        interval: root.processTimeoutMs
        repeat: false
        onTriggered: {
            if (proc.running) {
                console.warn("DataModule: process timeout for", root.path);
                proc.running = false;
                root.hasError = true;
                root.loading = false;
                crashRestart.interval = root.backoffMs;
                crashRestart.restart();
            }
        }
    }

    Timer {
        id: crashRestart

        repeat: false
        onTriggered: {
            if (!proc.running) {
                root.backoffMs = Math.min(root.backoffMs * 2, 30000);
                crashRestart.interval = root.backoffMs;
                proc.running = true;
                if (!pollTimer.running)
                    pollTimer.start();

            }
        }
    }

    Timer {
        id: pollTimer

        interval: root.interval
        repeat: true
        running: false
        onTriggered: {
            if (!proc.running)
                proc.running = true;

        }
    }

    Timer {
        id: startTimer

        interval: 1000 + Math.random() * 2000
        repeat: false
        running: true
        onTriggered: {
            proc.running = true;
            pollTimer.start();
        }
    }

}
