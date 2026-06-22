import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

QtObject {
    id: theme

    readonly property string fontFamily: "GohuFont 11 Nerd Font"
    property color bg: "#1a1110"
    property color fg: "#f1dfdb"
    property color surface: "#271d1c"
    property color surfaceLighter: "#322826"
    property color primary: "#ffb4a7"
    property color muted: "#66f1dfdb"
    property color error: "#ffb4ab"
    property color warning: "#ddc48c"
    property color green: "#A6DA95"
    property color blue: "#8AADF4"
    readonly property real barOpacity: 0.65
    readonly property int barHeight: 38
    readonly property string home: Quickshell.env("HOME")
    readonly property string helperDir: home + "/.config/quickshell/helpers"
    readonly property string cacheDir: home + "/.cache/quickshell"
    readonly property string tmpDir: "/tmp/quickshell"
    property FileView colorsWatcher

    function bin(name) {
        return helperDir + "/" + name;
    }

    function config(path) {
        return home + "/.config/" + path;
    }

    Behavior on bg {
        ColorAnimation {
            duration: 200
            easing.type: Easing.InOutQuad
        }

    }

    Behavior on fg {
        SequentialAnimation {
            PauseAnimation {
                duration: 30
            }

            ColorAnimation {
                duration: 100
                easing.type: Easing.InOutQuad
            }

        }

    }

    Behavior on surface {
        SequentialAnimation {
            PauseAnimation {
                duration: 60
            }

            ColorAnimation {
                duration: 100
                easing.type: Easing.InOutQuad
            }

        }

    }

    Behavior on surfaceLighter {
        SequentialAnimation {
            PauseAnimation {
                duration: 90
            }

            ColorAnimation {
                duration: 100
                easing.type: Easing.InOutQuad
            }

        }

    }

    Behavior on primary {
        SequentialAnimation {
            PauseAnimation {
                duration: 120
            }

            ColorAnimation {
                duration: 100
                easing.type: Easing.InOutQuad
            }

        }

    }

    Behavior on muted {
        SequentialAnimation {
            PauseAnimation {
                duration: 150
            }

            ColorAnimation {
                duration: 100
                easing.type: Easing.InOutQuad
            }

        }

    }

    Behavior on error {
        SequentialAnimation {
            PauseAnimation {
                duration: 180
            }

            ColorAnimation {
                duration: 100
                easing.type: Easing.InOutQuad
            }

        }

    }

    Behavior on warning {
        SequentialAnimation {
            PauseAnimation {
                duration: 210
            }

            ColorAnimation {
                duration: 100
                easing.type: Easing.InOutQuad
            }

        }

    }

    Behavior on green {
        SequentialAnimation {
            PauseAnimation {
                duration: 240
            }

            ColorAnimation {
                duration: 100
                easing.type: Easing.InOutQuad
            }

        }

    }

    Behavior on blue {
        SequentialAnimation {
            PauseAnimation {
                duration: 270
            }

            ColorAnimation {
                duration: 100
                easing.type: Easing.InOutQuad
            }

        }

    }

    Component.onCompleted: {
        var comp = Qt.createComponent("file://" + home + "/.cache/quickshell/Colors.qml");
        if (comp !== null && comp.status === Component.Ready) {
            var c = comp.createObject(theme);
            if (c !== null) {
                theme.bg = c.bg;
                theme.fg = c.fg;
                theme.surface = c.surface;
                theme.surfaceLighter = c.surfaceLighter;
                theme.primary = c.primary;
                theme.muted = c.muted;
                theme.error = c.error;
                theme.warning = c.warning;
                theme.green = c.green;
                theme.blue = c.blue;
                c.destroy();
            }
        }
    }

    colorsWatcher: FileView {
        path: "file://" + home + "/.cache/quickshell/colors.json"
        watchChanges: true
        onLoaded: {
            var textVal = colorsWatcher.text().trim();
            if (textVal.length === 0)
                return ;

            var data;
            try {
                data = JSON.parse(textVal);
            } catch (e) {
                console.warn("Theme: failed to parse colors.json:", e, "data:", textVal.substring(0, 100));
                return;
            }

            if (typeof data !== "object" || data === null) {
                console.warn("Theme: colors.json is not an object:", typeof data);
                return;
            }

            if (data.bg) theme.bg = data.bg;
            if (data.fg) theme.fg = data.fg;
            if (data.surface) theme.surface = data.surface;
            if (data.surfaceLighter) theme.surfaceLighter = data.surfaceLighter;
            if (data.primary) theme.primary = data.primary;
            if (data.muted) theme.muted = data.muted;
            if (data.error) theme.error = data.error;
            if (data.warning) theme.warning = data.warning;
            if (data.green) theme.green = data.green;
            if (data.blue) theme.blue = data.blue;
        }
        onFileChanged: reload()
    }

}
