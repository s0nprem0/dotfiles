pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: theme

    readonly property string fontFamily: "GohuFont 11 Nerd Font"

    property color bg:            "#1a1110"
    Behavior on bg { SequentialAnimation { PauseAnimation { duration: 0 } ColorAnimation { duration: 200; easing.type: Easing.InOutQuad } } }
    property color fg:            "#f1dfdb"
    Behavior on fg { SequentialAnimation { PauseAnimation { duration: 30 } ColorAnimation { duration: 200; easing.type: Easing.InOutQuad } } }
    property color surface:       "#271d1c"
    Behavior on surface { SequentialAnimation { PauseAnimation { duration: 60 } ColorAnimation { duration: 200; easing.type: Easing.InOutQuad } } }
    property color surfaceLighter: "#322826"
    Behavior on surfaceLighter { SequentialAnimation { PauseAnimation { duration: 90 } ColorAnimation { duration: 200; easing.type: Easing.InOutQuad } } }
    property color primary:       "#ffb4a7"
    Behavior on primary { SequentialAnimation { PauseAnimation { duration: 120 } ColorAnimation { duration: 200; easing.type: Easing.InOutQuad } } }
    property color muted:         "#66f1dfdb"
    Behavior on muted { SequentialAnimation { PauseAnimation { duration: 150 } ColorAnimation { duration: 200; easing.type: Easing.InOutQuad } } }
    property color error:         "#ffb4ab"
    Behavior on error { SequentialAnimation { PauseAnimation { duration: 180 } ColorAnimation { duration: 200; easing.type: Easing.InOutQuad } } }
    property color warning:       "#ddc48c"
    Behavior on warning { SequentialAnimation { PauseAnimation { duration: 210 } ColorAnimation { duration: 200; easing.type: Easing.InOutQuad } } }
    property color green:         "#A6DA95"
    Behavior on green { SequentialAnimation { PauseAnimation { duration: 240 } ColorAnimation { duration: 200; easing.type: Easing.InOutQuad } } }
    property color blue:          "#8AADF4"
    Behavior on blue { SequentialAnimation { PauseAnimation { duration: 270 } ColorAnimation { duration: 200; easing.type: Easing.InOutQuad } } }

    readonly property real barOpacity: 0.65
    readonly property int barHeight: 38

    readonly property string home:       Quickshell.env("HOME")
    readonly property string helperDir:  home + "/.config/quickshell/helpers"

    function bin(name) {
        return helperDir + "/" + name
    }

    function config(path) {
        return home + "/.config/" + path
    }

    property FileView colorsWatcher

    colorsWatcher: FileView {
        path: "file://" + home + "/.cache/quickshell/colors.json"
        watchChanges: true
        onLoaded: {
            try {
                var textVal = colorsWatcher.text().trim()
                if (textVal.length === 0) return
                var data = JSON.parse(textVal)
                if (data.bg)              theme.bg = data.bg
                if (data.fg)              theme.fg = data.fg
                if (data.surface)         theme.surface = data.surface
                if (data.surfaceLighter)  theme.surfaceLighter = data.surfaceLighter
                if (data.primary)         theme.primary = data.primary
                if (data.muted)           theme.muted = data.muted
                if (data.error)           theme.error = data.error
                if (data.warning)         theme.warning = data.warning
                if (data.green)           theme.green = data.green
                if (data.blue)            theme.blue = data.blue
            } catch (e) { console.warn("Theme: failed to parse colors.json:", e) }
        }
        onFileChanged: reload()
    }
}
