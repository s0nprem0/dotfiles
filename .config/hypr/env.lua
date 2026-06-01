-- █▀▀ █▄ █ █ █
-- ██▄ █ ▀█ ▀▄▀
-- Environment Variables for Hyprland (Lua Syntax)

-- Use the dedicated Lua API instead of `config.env`.
-- This sets compositor environment vars (and is the format used by the stock example).

-- Cursor
hl.env("HYPRCURSOR_THEME", "macOS")
hl.env("XCURSOR_THEME", "macOS")
hl.env("XCURSOR_SIZE", "20")
hl.env("HYPRCURSOR_SIZE", "20")

-- Qt / KDE
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")

-- GTK / Clutter
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("CLUTTER_BACKEND", "wayland")

-- System
hl.env("SSH_AUTH_SOCK", "$XDG_RUNTIME_DIR/keyring/ssh")
hl.env("BROWSER", "firefox")
