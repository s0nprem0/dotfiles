local mainMod = "SUPER"
local altMod = "ALT"

-- Zoom constants
local ZOOM_MIN = 1.0
local ZOOM_MAX = 3.0
local ZOOM_STEP = 0.3

local scripts = "~/.config/hypr/scripts/"
local qs_helpers = "~/.config/quickshell/helpers/"

local function exec(cmd)
	return hl.dsp.exec_cmd(cmd)
end
local function script(file)
	return exec(scripts .. file)
end
local function qs_helper(file)
	return exec(qs_helpers .. file)
end

local function qs_popup(key, popup_name, desc)
	hl.bind(mainMod .. " + " .. key, exec("qs ipc call shell togglePopup " .. popup_name), { description = desc })
end

local function osd_bind(key, args, desc, repeating)
	hl.bind(key, qs_helper("osdctl " .. args), { repeating = repeating or false, locked = true, description = desc })
end

hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exit(), { description = "Quit Hyprland" })
hl.bind(mainMod .. " + " .. altMod .. " + R", script("reload.sh"), { description = "Reload config" })
hl.bind(mainMod .. " + ESCAPE", exec("wlogout"), { description = "Power menu" })

hl.bind(mainMod .. " + RETURN", exec(terminal), { description = "Terminal" })
hl.bind(mainMod .. " + E", exec(fileManager), { description = "File manager" })
qs_popup("SPACE", "apps", "App launcher")
hl.bind(mainMod .. " + SHIFT + V", script("cliphist.sh menu"), { description = "Clipboard history" })

qs_popup("N", "ports", "Ports menu")
hl.bind(mainMod .. " + B", qs_helper("osdctl block bluetooth"), { description = "Toggle bluetooth" })

qs_popup("V", "clipboard", "Toggle clipboard popup")
qs_popup("COMMA", "emoji", "Toggle emoji picker")
qs_popup("G", "media", "Toggle media popup")
qs_popup("SHIFT + W", "network", "Toggle network popup")
qs_popup("SHIFT + N", "notifications", "Toggle notification center")
qs_popup("SHIFT + B", "battery", "Toggle battery popup")
qs_popup("SHIFT + E", "settings", "Toggle settings popup")
qs_popup("TAB", "workspace", "Toggle workspace overview")
qs_popup("SHIFT + slash", "shortcut", "Toggle shortcut cheatsheet")

hl.bind(mainMod .. " + W", hl.dsp.window.close(), { description = "Close window" })
hl.bind(mainMod .. " + SHIFT + W", exec("hyprctl kill"), { description = "Force kill window" })
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.window.pseudo(), { description = "Toggle pseudo-tile" })

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
	hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }),
	{ description = "Toggle fullscreen" }
)
hl.bind(
	mainMod .. " + M",
	hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }),
	{ description = "Toggle maximize" }
)
hl.bind(
	mainMod .. " + SHIFT + F",
	hl.dsp.window.fullscreen_state({ internal = 2, client = 0, action = "set" }),
	{ description = "FS state: fullscreen" }
)
hl.bind(
	mainMod .. " + SHIFT + G",
	hl.dsp.window.fullscreen_state({ internal = 0, client = 2, action = "set" }),
	{ description = "FS state: maximized" }
)

hl.bind(
	mainMod .. " + " .. altMod .. " + D",
	exec("hyprctl keyword general:layout dwindle"),
	{ description = "Layout: dwindle" }
)
hl.bind(
	mainMod .. " + " .. altMod .. " + M",
	exec("hyprctl keyword general:layout master"),
	{ description = "Layout: master" }
)

local dirs = { "left", "right", "up", "down" }
for _, dir in ipairs(dirs) do
	hl.bind(mainMod .. " + " .. dir, hl.dsp.focus({ direction = dir }), { description = "Focus " .. dir })
	hl.bind(
		mainMod .. " + SHIFT + " .. dir,
		hl.dsp.window.move({ direction = dir }),
		{ description = "Move window " .. dir }
	)
end

hl.bind(mainMod .. " + bracketleft", exec("hyprctl dispatch cyclenext prev"), { description = "Cycle windows: prev" })
hl.bind(mainMod .. " + bracketright", exec("hyprctl dispatch cyclenext"), { description = "Cycle windows: next" })

for i = 1, 9 do
	local ws = tostring(i)
	hl.bind(mainMod .. " + " .. ws, hl.dsp.focus({ workspace = ws }), { description = "Workspace: " .. ws })
	hl.bind(
		mainMod .. " + SHIFT + " .. ws,
		hl.dsp.window.move({ workspace = ws }),
		{ description = "Move window to workspace " .. ws }
	)
end

hl.bind(mainMod .. " + 0", hl.dsp.focus({ workspace = "10" }), { description = "Workspace: 10" })
hl.bind(
	mainMod .. " + SHIFT + 0",
	hl.dsp.window.move({ workspace = "10" }),
	{ description = "Move window to workspace 10" }
)

hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"), { description = "Toggle scratchpad" })
hl.bind(
	mainMod .. " + SHIFT + S",
	hl.dsp.window.move({ workspace = "special:magic" }),
	{ description = "Move window to scratchpad" }
)

osd_bind("XF86AudioRaiseVolume", "volume up", "Volume up", true)
osd_bind("XF86AudioLowerVolume", "volume down", "Volume down", true)
osd_bind("XF86AudioMute", "volume mute", "Mute toggle")
osd_bind("XF86AudioMicMute", "volume mic-mute", "Mic mute toggle")

osd_bind("XF86MonBrightnessUp", "brightness up", "Brightness up", true)
osd_bind("XF86MonBrightnessDown", "brightness down", "Brightness down", true)

osd_bind("XF86KbdBrightnessUp", "kbdbrightness up", "Kbd backlight up", true)
osd_bind("XF86KbdBrightnessDown", "kbdbrightness down", "Kbd backlight down", true)
hl.bind(
	mainMod .. " + " .. altMod .. " + K",
	qs_helper("osdctl kbdbrightness cycle"),
	{ description = "Kbd backlight cycle up" }
)
hl.bind(
	mainMod .. " + " .. altMod .. " + SHIFT + K",
	qs_helper("osdctl kbdbrightness cycle-rev"),
	{ description = "Kbd backlight cycle down" }
)

hl.bind("Caps_Lock", qs_helper("lock_osd.sh Caps_Lock"), { locked = true, description = "Caps Lock indicator" })
hl.bind("Num_Lock", qs_helper("lock_osd.sh Num_Lock"), { locked = true, description = "Num Lock indicator" })

hl.bind("XF86AudioNext", exec("playerctl next"), { locked = true, description = "Media: next" })
hl.bind("XF86AudioPrev", exec("playerctl previous"), { locked = true, description = "Media: previous" })
hl.bind("XF86AudioPlay", exec("playerctl play-pause"), { locked = true, description = "Media: play/pause" })
hl.bind("XF86AudioPause", exec("playerctl play-pause"), { locked = true, description = "Media: pause" })

hl.bind("Print", qs_helper("screenshot full"), { description = "Screenshot: full" })
hl.bind(mainMod .. " + SHIFT + R", qs_helper("screenshot region"), { description = "Screenshot: region" })
hl.bind(mainMod .. " + Print", qs_helper("screenshot active"), { description = "Screenshot: active" })
hl.bind(mainMod .. " + SHIFT + X", qs_helper("screenshot ocr"), { description = "Screenshot: OCR region" })

local function zoomfunction(value)
	local zoomvalue = hl.get_config("cursor:zoom_factor")
	local new_zoom = math.max(ZOOM_MIN, math.min(ZOOM_MAX, zoomvalue + value))
	hl.config({ cursor = { zoom_factor = new_zoom } })
end

hl.bind(mainMod .. " + Minus", function()
	zoomfunction(-ZOOM_STEP)
end, { repeating = true, description = "Zoom out" })
hl.bind(mainMod .. " + Equal", function()
	zoomfunction(ZOOM_STEP)
end, { repeating = true, description = "Zoom in" })
hl.bind(mainMod .. " + code:82", function()
	zoomfunction(-ZOOM_STEP)
end, { repeating = true, description = "Zoom out (keypad)" })
hl.bind(mainMod .. " + code:86", function()
	zoomfunction(ZOOM_STEP)
end, { repeating = true, description = "Zoom in (keypad)" })

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Window: drag" })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Window: resize" })
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "Workspace: next" })
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }), { description = "Workspace: prev" })

local monitors = require("monitors")

qs_popup("p", "power", "Power menu")
qs_popup("d", "presentation", "Display: Toggle modes")

hl.bind(mainMod .. " + D", qs_helper("display_toggle toggle"), { description = "Display: Toggle mode" })
