-- Auto-generated from ~/.config/hypr/binds.conf
-- This file was missing; keeping it to satisfy `require("binds")` in hyprland.lua.
-- Note: Hyprland's Lua config API changed; if a bind here fails, use binds.conf instead.

local mainMod = "SUPER"
local altMod = "ALT"

-- System & Session
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exit())
hl.bind(mainMod .. " + " .. altMod .. " + R", hl.dsp.exec_cmd("~/.config/hypr/scripts/reload.sh"))

-- Application Launchers
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(menu))

-- Window Management
hl.bind(mainMod .. " + W", hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("hyprctl kill"))

hl.bind(mainMod .. " + F", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + T", hl.dsp.window.fullscreen(0))
hl.bind(mainMod .. " + M", hl.dsp.window.fullscreen(1))
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.window.pseudo())

-- Navigation
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

-- BSPWM-style Cycling
hl.bind(mainMod .. " + bracketleft", hl.dsp.exec_cmd("hyprctl dispatch cyclenext prev"))
hl.bind(mainMod .. " + bracketright", hl.dsp.exec_cmd("hyprctl dispatch cyclenext"))

-- Layout Control
hl.bind(mainMod .. " + " .. altMod .. " + D", hl.dsp.exec_cmd("hyprctl keyword general:layout dwindle"))
hl.bind(mainMod .. " + " .. altMod .. " + M", hl.dsp.exec_cmd("hyprctl keyword general:layout master"))

-- Workspace Management
for i = 1, 9 do
	hl.bind(mainMod .. " + " .. i, hl.dsp.focus({ workspace = tostring(i) }))
	hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = tostring(i) }))
end
hl.bind(mainMod .. " + 0", hl.dsp.focus({ workspace = "10" }))
hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = "10" }))

-- Special Workspace (Scratchpad)
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Volume
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

-- Media Control
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })

-- Wallpaper / Theme
hl.bind(
	mainMod .. " + " .. altMod .. " + W",
	hl.dsp.exec_cmd("~/.config/hypr/scripts/wallpaper.sh ~/Pictures/lain2.jpg")
)

-- Screenshots
hl.bind("Print", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh full"))
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh region"))
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh active"))

-- Mouse Controls
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
