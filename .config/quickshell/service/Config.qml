pragma Singleton
import Quickshell
import QtQuick

QtObject {
    readonly property string terminal: Quickshell.env("TERMINAL") || "kitty"

    readonly property var impalaCmd: [
        "hyprctl", "dispatch", "exec",
        "[float;size 55% 65%;center] " + terminal + " -T impala impala"
    ]
}
