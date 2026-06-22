import QtQuick

QtObject {
    readonly property color bg: "{{colors.background.default.hex}}"
    readonly property color fg: "{{colors.on_surface.default.hex}}"
    readonly property color surface: "{{colors.surface_container.default.hex}}"
    readonly property color surfaceLighter: "{{colors.surface_container_high.default.hex}}"
    readonly property color primary: "{{colors.primary.default.hex}}"
    readonly property color muted: "#66{{colors.on_surface.default.hex_stripped}}"
    readonly property color error: "{{colors.error.default.hex}}"
    readonly property color warning: "{{colors.tertiary.default.hex}}"
    readonly property color green: "{{colors.tertiary.default.hex}}"
    readonly property color blue: "{{colors.secondary.default.hex}}"
}
