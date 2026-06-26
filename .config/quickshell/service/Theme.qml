import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

Item {
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
    property color tertiary: "#271d1c"
    readonly property string surfaceContainer: surface
    readonly property string surfaceHover: surfaceLighter
    readonly property string surfaceHighlight: surfaceLighter
    readonly property string border: surfaceLighter
    readonly property string textDisabled: fg + "80"
    readonly property string textAccent: primary
    readonly property string success: green
    readonly property string info: blue
    readonly property real barOpacity: 0.65
    readonly property color primaryAlpha005: Qt.alpha(primary, 0.05)
    readonly property color primaryAlpha008: Qt.alpha(primary, 0.08)
    readonly property color primaryAlpha01: Qt.alpha(primary, 0.1)
    readonly property color primaryAlpha012: Qt.alpha(primary, 0.12)
    readonly property color primaryAlpha015: Qt.alpha(primary, 0.15)
    readonly property color primaryAlpha018: Qt.alpha(primary, 0.18)
    readonly property color primaryAlpha02: Qt.alpha(primary, 0.2)
    readonly property color primaryAlpha025: Qt.alpha(primary, 0.25)
    readonly property color primaryAlpha03: Qt.alpha(primary, 0.3)
    readonly property color primaryAlpha035: Qt.alpha(primary, 0.35)
    readonly property color primaryAlpha04: Qt.alpha(primary, 0.4)
    readonly property color primaryAlpha05: Qt.alpha(primary, 0.5)
    readonly property color primaryAlpha06: Qt.alpha(primary, 0.6)
    readonly property int fontSizeXxs: 7
    readonly property int fontSizeXs: 8
    readonly property int fontSizeSm: 9
    readonly property int fontSizeMd: 10
    readonly property int fontSizeLg: 11
    readonly property int fontSizeXl: 12
    readonly property int fontSize2xl: 13
    readonly property int fontSize3xl: 14
    readonly property int fontSize4xl: 16
    readonly property int fontSize5xl: 18
    readonly property int fontSize6xl: 20
    readonly property int fontSize7xl: 24
    readonly property int fontSize8xl: 28
    readonly property int fontSize9xl: 36
    readonly property int settingsWidth: 720
    readonly property int settingsHeight: 560
    readonly property int settingsMinWidth: 640
    readonly property int settingsMinHeight: 520
    readonly property int barHeight: 38
    readonly property string home: Quickshell.env("HOME")
    readonly property string helperDir: home + "/.config/quickshell/helpers"
    readonly property string cacheDir: home + "/.cache/quickshell"
    readonly property string tmpDir: "/tmp/quickshell"
    property bool glassEnabled: true
    property color popupBgColor: glassEnabled ? Qt.rgba(bg.r, bg.g, bg.b, 0.5) : bg
    property FileView glassState

    glassState: FileView {
        path: "file:///tmp/quickshell_glass_state"
        watchChanges: true
        onLoaded: {
            var val = glassState.text().trim();
            theme.glassEnabled = (val !== "false");
        }
        onFileChanged: reload()
    }

    function bin(name) {
        return helperDir + "/" + name;
    }

    function config(path) {
        return home + "/.config/" + path;
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
                theme.tertiary = c.tertiary !== undefined ? c.tertiary : c.surface;
                c.destroy();
            }
        }
    }
    FileView {
        id: colorsWatcher

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
                return ;
            }
            if (typeof data !== "object" || data === null) {
                console.warn("Theme: colors.json is not an object:", typeof data);
                return ;
            }
            if (data.bg)
                theme.bg = data.bg;

            if (data.fg)
                theme.fg = data.fg;

            if (data.surface)
                theme.surface = data.surface;

            if (data.surfaceLighter)
                theme.surfaceLighter = data.surfaceLighter;

            if (data.primary)
                theme.primary = data.primary;

            if (data.muted)
                theme.muted = data.muted;

            if (data.error)
                theme.error = data.error;

            if (data.warning)
                theme.warning = data.warning;

            if (data.green)
                theme.green = data.green;

            if (data.blue)
                theme.blue = data.blue;

            if (data.tertiary)
                theme.tertiary = data.tertiary;

        }
        onFileChanged: reload()
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

}
