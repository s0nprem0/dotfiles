pragma Singleton
import Quickshell
import QtQuick

QtObject {
    readonly property string terminal: "kitty"

    readonly property var impalaCmd: [
        "hyprctl", "dispatch", "exec",
        "[float;size 55% 65%;center] kitty -T impala impala"
    ]
}
