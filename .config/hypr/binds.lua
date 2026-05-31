local mainMod = "SUPER"
local altMod = "ALT"

-- System
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exit())
hl.bind(mainMod .. " + " .. altMod .. " + R", hl.dsp.exec_cmd("~/.config/hypr/scripts/reload.sh"))

-- Launchers
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(menu))

-- Windows
hl.bind(mainMod .. " + W", hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("hyprctl kill"))

hl.bind(mainMod .. " + F", hl.dsp.window.float({ action = "toggle" }))

hl.bind(
	mainMod .. " + T",
	hl.dsp.window.fullscreen({
		mode = "fullscreen",
		action = "toggle",
	})
)

hl.bind(
	mainMod .. " + M",
	hl.dsp.window.fullscreen({
		mode = "maximized",
		action = "toggle",
	})
)

hl.bind(
	mainMod .. " + SHIFT + F",
	hl.dsp.window.fullscreen_state({
		internal = 2,
		client = 0,
		action = "set",
	})
)

hl.bind(
	mainMod .. " + SHIFT + G",
	hl.dsp.window.fullscreen_state({
		internal = 0,
		client = 2,
		action = "set",
	})
)

hl.bind(mainMod .. " + SHIFT + T", hl.dsp.window.pseudo())

-- Navigation
for _, dir in ipairs({ "left", "right", "up", "down" }) do
	hl.bind(mainMod .. " + " .. dir, hl.dsp.focus({ direction = dir }))
end

-- Window Cycling
hl.bind(mainMod .. " + bracketleft", hl.dsp.exec_cmd("hyprctl dispatch cyclenext prev"))

hl.bind(mainMod .. " + bracketright", hl.dsp.exec_cmd("hyprctl dispatch cyclenext"))

-- Layouts
hl.bind(mainMod .. " + " .. altMod .. " + D", hl.dsp.exec_cmd("hyprctl keyword general:layout dwindle"))

hl.bind(mainMod .. " + " .. altMod .. " + M", hl.dsp.exec_cmd("hyprctl keyword general:layout master"))

-- Workspaces
for i = 1, 9 do
	local ws = tostring(i)

	hl.bind(mainMod .. " + " .. ws, hl.dsp.focus({ workspace = ws }))

	hl.bind(mainMod .. " + SHIFT + " .. ws, hl.dsp.window.move({ workspace = ws }))
end

hl.bind(mainMod .. " + 0", hl.dsp.focus({ workspace = "10" }))
hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = "10" }))

-- Scratchpad
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))

hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Audio
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"),
	{ repeating = true, locked = true }
)

hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ repeating = true, locked = true }
)

hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
	{ repeating = true, locked = true }
)

-- Brightness
hl.bind(
	"XF86MonBrightnessUp",
	hl.dsp.exec_cmd("~/.config/hypr/scripts/brightnessctl.sh up"),
	{ repeating = true, locked = true }
)

hl.bind(
	"XF86MonBrightnessDown",
	hl.dsp.exec_cmd("~/.config/hypr/scripts/brightnessctl.sh down"),
	{ repeating = true, locked = true }
)

-- Keyboard Backlight
hl.bind(
	"XF86KbdBrightnessUp",
	hl.dsp.exec_cmd("~/.config/hypr/scripts/kbd_brightnessctl.sh up"),
	{ repeating = true, locked = true }
)

hl.bind(
	"XF86KbdBrightnessDown",
	hl.dsp.exec_cmd("~/.config/hypr/scripts/kbd_brightnessctl.sh down"),
	{ repeating = true, locked = true }
)

hl.bind(mainMod .. " + " .. altMod .. " + K", hl.dsp.exec_cmd("~/.config/hypr/scripts/kbd_brightnessctl.sh up"))

-- Media
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })

-- Wallpaper
hl.bind(
	mainMod .. " + " .. altMod .. " + W",
	hl.dsp.exec_cmd("~/.config/hypr/scripts/wallpaper.sh ~/Pictures/lain2.jpg")
)

-- Screenshots
hl.bind("Print", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh full"))
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh region"))
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh active"))

-- Mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))

hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
