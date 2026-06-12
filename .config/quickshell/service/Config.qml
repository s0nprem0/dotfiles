import QtQuick
import Quickshell
pragma Singleton

QtObject {
    readonly property string terminal: Quickshell.env("TERMINAL") || "kitty"
    readonly property var impalaCmd: [terminal, "--title", "impala", "-e", "/usr/sbin/impala"]
    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/quickshell"
}
