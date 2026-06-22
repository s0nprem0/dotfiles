import QtQuick
import Quickshell
pragma Singleton

QtObject {
    readonly property string terminal: Quickshell.env("TERMINAL") || "kitty"
    readonly property string impalaPath: Quickshell.env("IMPALA") || "/usr/sbin/impala"
    readonly property var impalaCmd: [terminal, "--title", "impala", "-e", impalaPath]
}
