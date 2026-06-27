import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

Item {
    readonly property string terminal: Quickshell.env("TERMINAL") || "kitty"
    property string impalaPath: Quickshell.env("IMPALA") || "/usr/sbin/impala"
    property var impalaCmd: [terminal, "--title", "impala", "-e", impalaPath]

    onImpalaPathChanged: impalaCmd = [terminal, "--title", "impala", "-e", impalaPath]

    Process {
        command: ["sh", "-c", "command -v impala || echo /usr/sbin/impala"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var p = this.text.trim();
                if (p) impalaPath = p;
            }
        }
    }
}
