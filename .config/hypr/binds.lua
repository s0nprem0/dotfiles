local mainMod = "SUPER"
local altMod = "ALT"

-- System
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exit(), { description = "Quit Hyprland" })
hl.bind(mainMod .. " + " .. altMod .. " + R", hl.dsp.exec_cmd("~/.config/hypr/scripts/reload.sh"), { description = "Reload config" })
hl.bind(mainMod .. " + ESCAPE", hl.dsp.exec_cmd("wlogout"), { description = "Power menu" })

-- Launchers
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal), { description = "Terminal" })
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager), { description = "File manager" })
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(menu), { description = "App launcher" })
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("~/.config/hypr/scripts/cliphist.sh menu"), { description = "Clipboard history" })

hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("rofi -show network -theme ~/.config/rofi/wifi.rasi"), { description = "Network menu" })
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("rofi -show bt -theme ~/.config/rofi/bluetooth.rasi"), { description = "Bluetooth menu" })

-- Windows
hl.bind(mainMod .. " + W", hl.dsp.window.close(), { description = "Close window" })
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("hyprctl kill"), { description = "Force kill window" })

hl.bind(mainMod .. " + F", function()
	local w = hl.get_active_window()
	if not w then
		hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
		return
	end

	local was_floating = w.floating
	local internal = w.fullscreen or 0
	local client = w.fullscreen_client or w.fullscreenClient or 0

	if internal ~= 0 or client ~= 0 then
		hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 0, client = 0, action = "set" }))
	end

	hl.dispatch(hl.dsp.window.float({ action = "toggle" }))

	if not was_floating then
		hl.exec_cmd("hyprctl dispatch centerwindow")
	end
end, { description = "Toggle float" })

hl.bind(
	mainMod .. " + T",
	hl.dsp.window.fullscreen({
		mode = "fullscreen",
		action = "toggle",
	}),
	{ description = "Toggle fullscreen" }
)

hl.bind(
	mainMod .. " + M",
	hl.dsp.window.fullscreen({
		mode = "maximized",
		action = "toggle",
	}),
	{ description = "Toggle maximize" }
)

hl.bind(
	mainMod .. " + SHIFT + F",
	hl.dsp.window.fullscreen_state({
		internal = 2,
		client = 0,
		action = "set",
	}),
	{ description = "FS state: fullscreen" }
)

hl.bind(
	mainMod .. " + SHIFT + G",
	hl.dsp.window.fullscreen_state({
		internal = 0,
		client = 2,
		action = "set",
	}),
	{ description = "FS state: maximized" }
)

-- # zoom
local function zoomfunction(value)
	local zoomvalue = hl.get_config("cursor:zoom_factor")
	if (zoomvalue + value) > 3.0 then
		hl.config({ cursor = { zoom_factor = 3.0 } })
	elseif (zoomvalue + value) < 1.0 then
		hl.config({ cursor = { zoom_factor = 1.0 } })
	else
		hl.config({ cursor = { zoom_factor = zoomvalue + value } })
	end
end

hl.bind("SUPER + Minus", function()
	zoomfunction(-0.3)
end, { repeating = true, description = "Zoom out" })
hl.bind("SUPER + Equal", function()
	zoomfunction(0.3)
end, { repeating = true, description = "Zoom in" })

--# Zoom with keypad
hl.bind("SUPER + code:82", function()
	zoomfunction(-0.3)
end, { repeating = true, description = "Zoom out (keypad)" })
hl.bind("SUPER + code:86", function()
	zoomfunction(0.3)
end, { repeating = true, description = "Zoom in (keypad)" })

hl.bind(mainMod .. " + SHIFT + T", hl.dsp.window.pseudo(), { description = "Toggle pseudo-tile" })

-- Navigation
for _, dir in ipairs({ "left", "right", "up", "down" }) do
	hl.bind(mainMod .. " + " .. dir, hl.dsp.focus({ direction = dir }), { description = "Focus " .. dir })
end

-- Move Windows
for _, dir in ipairs({ "left", "right", "up", "down" }) do
	hl.bind(mainMod .. " + SHIFT + " .. dir, hl.dsp.window.move({ direction = dir }), { description = "Move window " .. dir })
end

-- Window Cycling
hl.bind(mainMod .. " + bracketleft", hl.dsp.exec_cmd("hyprctl dispatch cyclenext prev"), { description = "Cycle windows: prev" })

hl.bind(mainMod .. " + bracketright", hl.dsp.exec_cmd("hyprctl dispatch cyclenext"), { description = "Cycle windows: next" })

-- Layouts
hl.bind(mainMod .. " + " .. altMod .. " + D", hl.dsp.exec_cmd("hyprctl keyword general:layout dwindle"), { description = "Layout: dwindle" })

hl.bind(mainMod .. " + " .. altMod .. " + M", hl.dsp.exec_cmd("hyprctl keyword general:layout master"), { description = "Layout: master" })

-- Workspaces
for i = 1, 9 do
	local ws = tostring(i)

	hl.bind(mainMod .. " + " .. ws, hl.dsp.focus({ workspace = ws }), { description = "Workspace: " .. ws })

	hl.bind(mainMod .. " + SHIFT + " .. ws, hl.dsp.window.move({ workspace = ws }), { description = "Move window to workspace " .. ws })
end

hl.bind(mainMod .. " + 0", hl.dsp.focus({ workspace = "10" }), { description = "Workspace: 10" })
hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = "10" }), { description = "Move window to workspace 10" })

-- Scratchpad
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"), { description = "Toggle scratchpad" })

hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }), { description = "Move window to scratchpad" })

-- Audio
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"),
	{ repeating = true, locked = true, description = "Volume up" }
)

hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ repeating = true, locked = true, description = "Volume down" }
)

hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
	{ locked = true, description = "Mute toggle" }
)

-- Brightness
hl.bind(
	"XF86MonBrightnessUp",
	hl.dsp.exec_cmd("~/.config/hypr/scripts/brightnessctl.sh up"),
	{ repeating = true, locked = true, description = "Brightness up" }
)

hl.bind(
	"XF86MonBrightnessDown",
	hl.dsp.exec_cmd("~/.config/hypr/scripts/brightnessctl.sh down"),
	{ repeating = true, locked = true, description = "Brightness down" }
)

-- Keyboard Backlight
hl.bind(
	"XF86KbdBrightnessUp",
	hl.dsp.exec_cmd("~/.config/hypr/scripts/kbd_brightnessctl.sh up"),
	{ repeating = true, locked = true, description = "Kbd backlight up" }
)

hl.bind(
	"XF86KbdBrightnessDown",
	hl.dsp.exec_cmd("~/.config/hypr/scripts/kbd_brightnessctl.sh down"),
	{ repeating = true, locked = true, description = "Kbd backlight down" }
)

hl.bind(mainMod .. " + " .. altMod .. " + K", hl.dsp.exec_cmd("~/.config/hypr/scripts/kbd_brightnessctl.sh up"), { description = "Kbd backlight up (alt)" })

-- Media
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true, description = "Media: next" })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true, description = "Media: previous" })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Media: play/pause" })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Media: pause" })

-- Screenshots
hl.bind("Print", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh full"), { description = "Screenshot: full" })
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh region"), { description = "Screenshot: region" })
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh active"), { description = "Screenshot: active" })

-- Mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Window: drag" })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Window: resize" })

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "Workspace: next" })

hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }), { description = "Workspace: prev" })
