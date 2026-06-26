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
            "footclient": "foot",
            "ghostty": "com.mitchellh.ghostty",
            "google-chrome": "google-chrome",
            "kitty": "kitty",
            "org.wezfurlong.wezterm": "org.wezfurlong.wezterm",
            "steam": "steam",
            "thunar": "org.xfce.thunar",
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

        return "application-x-executable";
    }

    function nerdFontGlyph(appName) {
        var name = (appName || "").toLowerCase();
        var glyphs = {
            "discord": "\ue96f",
            "firefox": "\ue189",
            "spotify": "\ue107",
            "telegram": "\ue0c7",
            "whatsapp": "\ue663",
            "signal": "\ue2bd",
            "slack": "\ue191"
        };
        for (var key in glyphs) {
            if (name.includes(key))
                return glyphs[key];

        }
        return "\ue08a";
    }

    function resolveWithFallback(iconName, wmClass, exec, desktopId, flatpakId, snapId) {
        if (!iconName)
            iconName = "";

        var candidates = [];
        if (desktopId)
            candidates.push(desktopId);

        if (flatpakId)
            candidates.push(flatpakId);

        if (snapId)
            candidates.push(snapId);

        if (wmClass)
            candidates.push(wmClass);

        if (exec)
            candidates.push(exec);

        for (var i = 0; i < candidates.length; i++) {
            var resolved = resolveDesktopIcon(candidates[i]);
            if (resolved)
                return resolved;

        }
        if (iconName && iconName.indexOf("/") !== 0) {
            var direct = resolveDesktopIcon(iconName);
            if (direct)
                return direct;

        }
        return "application-x-executable";
    }

}
