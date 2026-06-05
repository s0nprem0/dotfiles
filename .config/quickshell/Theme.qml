pragma Singleton
import Quickshell
import QtQuick

QtObject {
    readonly property string fontFamily: "GohuFont 11 Nerd Font"

    readonly property color bg:            "#1a1110"
    readonly property color fg:            "#f1dfdb"
    readonly property color surface:       "#271d1c"
    readonly property color surfaceLighter: "#3D2826"
    readonly property color primary:       "#ffb4a7"
    readonly property color muted:         "#66f1dfdb"
    readonly property color error:         "#f38ba8"
    readonly property color warning:       "#f9e2af"
    readonly property color green:         "#A6DA95"
    readonly property color blue:          "#8AADF4"

    readonly property string home:       Quickshell.env("HOME")
    readonly property string helperDir:  home + "/.config/quickshell/helpers"

    function bin(name) {
        return helperDir + "/" + name
    }

    function config(path) {
        return home + "/.config/" + path
    }
}
