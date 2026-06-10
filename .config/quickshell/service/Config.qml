pragma Singleton
import Quickshell
import QtQuick

QtObject {
    readonly property string terminal: Quickshell.env("TERMINAL") || "kitty"

    readonly property var impalaCmd: [
        terminal, "--title", "impala", "-e", "/usr/sbin/impala"
    ]

    readonly property string helperDir: Quickshell.env("HOME") + "/.config/quickshell/helpers"
}
