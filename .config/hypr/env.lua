-- █▀▀ █▄ █ █ █
-- ██▄ █ ▀█ ▀▄▀
-- Environment Variables for Hyprland (Lua Syntax)

hl.config({
	env = {
		-- Cursor
		"HYPRCURSOR_THEME,macOS",
		"XCURSOR_THEME,macOS",
		"XCURSOR_SIZE,24",
		"HYPRCURSOR_SIZE,24",

		-- Qt / KDE
		"QT_QPA_PLATFORMTHEME,qt6ct",
		"QT_QPA_PLATFORM,wayland",
		"QT_AUTO_SCREEN_SCALE_FACTOR,1",
		"QT_WAYLAND_DISABLE_WINDOWDECORATION,1",

		-- GTK / Clutter
		"GDK_BACKEND,wayland,x11",
		"CLUTTER_BACKEND,wayland",

		-- System
		"SSH_AUTH_SOCK,$XDG_RUNTIME_DIR/keyring/ssh",
		"BROWSER,firefox",
	},
})
