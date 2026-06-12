import QtQuick
import Quickshell
pragma Singleton

QtObject {
    function resolveDesktopIcon(name) {
        if (!name)
            return "";

        var substitutions = {
            "code": "visual-studio-code",
            "code-url-handler": "visual-studio-code",
            "code-insiders": "visual-studio-code-insiders",
            "codium": "vscodium",
            "ghostty": "com.mitchellh.ghostty",
            "google-chrome": "google-chrome",
            "org.wezfurlong.wezterm": "org.wezfurlong.wezterm",
            "vesktop": "vesktop",
            "wezterm": "org.wezfurlong.wezterm",
            "zen": "zen-browser"
        };
        var lower = name.toLowerCase();
        if (substitutions[name] && Quickshell.iconPath(substitutions[name], true))
            return substitutions[name];

        if (substitutions[lower] && Quickshell.iconPath(substitutions[lower], true))
            return substitutions[lower];

        if (Quickshell.iconPath(name, true))
            return name;

        if (Quickshell.iconPath(lower, true))
            return lower;

        var lastDomainPart = name.split(".").pop();
        if (lastDomainPart && Quickshell.iconPath(lastDomainPart, true))
            return lastDomainPart;

        if (lastDomainPart && Quickshell.iconPath(lastDomainPart.toLowerCase(), true))
            return lastDomainPart.toLowerCase();

        var kebab = lower.replace(/\s+/g, "-").replace(/_/g, "-");
        if (Quickshell.iconPath(kebab, true))
            return kebab;

        return "";
    }

    function nerdFontGlyph(appName) {
        var name = (appName || "").toLowerCase();
        var glyphs = {
            "discord": "󰙯",
            "firefox": "󰈹",
            "spotify": "󰓇",
            "telegram": "",
            "whatsapp": "󰖣",
            "signal": "󰋽",
            "slack": "󰒱"
        };
        for (var key in glyphs) {
            if (name.includes(key))
                return glyphs[key];

        }
        return "󰂚";
    }

}
