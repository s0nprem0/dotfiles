-- █▀▄▀█ █▀█ █▄ █ █ ▀█▀ █▀█ █▀█
-- █ ▀ █ █▄█ █ ▀█ █  █  █▄█ █▀▄
-- Main Hyprland Configuration (Lua Syntax)

-- ==========================================
-- 1. Load Pre-requisite Modules
-- ==========================================
require("monitors")
require("defaultPrograms")

-- Assuming colors.lua defines global variables like `accent` and `surface`
require("colors")

-- ==========================================
-- 2. Core Configuration & Autostart
-- ==========================================

-- Autostart
hl.on("hyprland.start", function()
	hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
	hl.exec_cmd("/usr/lib/hyprpolkitagent/hyprpolkitagent")
	hl.exec_cmd("gnome-keyring-daemon --start --components=secrets,ssh")
	hl.exec_cmd("~/.config/hypr/scripts/usb-monitor.sh")
	hl.exec_cmd("~/.config/hypr/scripts/idle-inhibit.sh")
	hl.exec_cmd("waybar")
	hl.exec_cmd("hyprpaper")
	hl.exec_cmd("hypridle")
	hl.exec_cmd("swaync")
end)

	hl.config({

		-- General Layout & Borders
		general = {
		gaps_in = 3,
		gaps_out = 12,
		border_size = 2,
		-- Concatenating color variables pulled from colors.lua
		["col.active_border"] = "rgb(" .. accent .. ")",
		["col.inactive_border"] = "rgb(" .. surface .. ")",
		layout = "dwindle",
		allow_tearing = true,
	},

	-- Group Settings
	group = {
		-- Gradients are represented as { colors = { ... }, angle = deg }
		["col.border_active"] = { colors = { "rgba(90ceaaff)", "rgba(ecd3a0ff)" }, angle = 45 },
		["col.border_inactive"] = { colors = { "rgba(1e8b50d9)", "rgba(50b050d9)" }, angle = 45 },
		["col.border_locked_active"] = { colors = { "rgba(90ceaaff)", "rgba(ecd3a0ff)" }, angle = 45 },
		["col.border_locked_inactive"] = { colors = { "rgba(1e8b50d9)", "rgba(50b050d9)" }, angle = 45 },
	},

	-- Decoration & Blur
	decoration = {
		active_opacity = 1,
		inactive_opacity = 0.85,
		rounding = 5,

		-- Nested shadow settings
		shadow = {
			enabled = false,
			range = 3,
			render_power = 2,
		},

		blur = {
			enabled = false,
			size = 2,
			passes = 2,
			vibrancy_darkness = 1.3,
			new_optimizations = true,
			ignore_opacity = true,
			xray = false,
		},
	},

	-- Animations
	animations = {
		enabled = true,
		bezier = {
			"easeOutQuint,0.23,1,0.32,1",
			"easeInOutCubic,0.65,0.05,0.36,1",
			"linear,0,0,1,1",
			"almostLinear,0.5,0.5,0.75,1.0",
			"quick,0.15,0,0.1,1",
		},
		animation = {
			"global, 1, 10, default",
			"border, 1, 5.39, easeOutQuint",
			"windows, 1, 4.79, easeOutQuint",
			"windowsIn, 1, 4.1, easeOutQuint, popin 87%",
			"windowsOut, 1, 1.49, linear, popin 87%",
			"fadeIn, 1, 1.73, almostLinear",
			"fadeOut, 1, 1.46, almostLinear",
			"fade, 1, 3.03, quick",
			"layers, 1, 3.81, easeOutQuint",
			"layersIn, 1, 4, easeOutQuint, fade",
			"layersOut, 1, 1.5, linear, fade",
			"fadeLayersIn, 1, 1.79, almostLinear",
			"fadeLayersOut, 1, 1.39, almostLinear",
			"workspaces, 1, 1.94, almostLinear, fade",
			"workspacesIn, 1, 1.21, almostLinear, fade",
			"workspacesOut, 1, 1.94, almostLinear, fade",
		},
	},

	-- Master Layout specifics
	master = {
		new_status = "master",
	},

	-- Cursor behavior
	cursor = {
		no_hardware_cursors = false,
		enable_hyprcursor = true,
		hide_on_key_press = true,
		no_warps = true,
	},

	-- Miscellaneous
	misc = {
		force_default_wallpaper = 1,
		disable_hyprland_logo = true,
		enable_swallow = true,
		swallow_regex = "^(btop|htop|top|nvim|less|man|magic)$",
	},

	-- Input Devices
	input = {
		kb_layout = "us",
		kb_variant = "",
		kb_model = "",
		kb_options = "",
		kb_rules = "",
		follow_mouse = 2,
		sensitivity = 0.2,

		touchpad = {
			natural_scroll = true,
			scroll_factor = 0.5,
		},
	},

	-- XWayland
	xwayland = {
		force_zero_scaling = true,
	},
})

-- ==========================================
-- 3. Load Post-requisite Modules
-- ==========================================
require("env")
require("windowrules")
require("binds")
