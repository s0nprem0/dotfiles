-- ==========================================
-- 1. Load Pre-requisite Modules
-- ==========================================
pcall(require, "monitors")
require("defaultPrograms")

dofile(os.getenv("HOME") .. "/.config/hypr/colors.lua")

-- Environment should be set before we start any long-running processes.
require("env")

-- Workspace placement
hl.workspace_rule({ workspace = "1", monitor = "eDP-1", default = true })
hl.workspace_rule({ workspace = "2", monitor = "HDMI-A-1" })
hl.workspace_rule({ workspace = "3", monitor = "HDMI-A-1" })

-- ==========================================
-- 2. Core Configuration & Autostart
-- ==========================================

-- Autostart
require("autostart")

hl.config({

	-- General Layout & Borders
	general = {
		gaps_in = 3,
		gaps_out = 12,
		border_size = 2,
		-- Concatenating color variables pulled from colors.lua
		["col.active_border"] = "rgb(" .. accent .. ")",
		["col.inactive_border"] = "rgb(" .. surface .. ")",
		layout = "master",
		allow_tearing = true,
		resize_on_border = true,
		snap = {
			enabled = true,
			window_gap = 4,
			monitor_gap = 5,
			respect_gaps = true,
		},
	},

	-- Decoration & Blur
	decoration = {
		active_opacity = 1,
		inactive_opacity = 1,
		rounding = 2,

		-- Nested shadow settings
		shadow = {
			enabled = false,
			range = 3,
			render_power = 2,
		},

		-- dim
		dim_inactive = true,
		dim_strength = 0.05,
		dim_special = 0.2,
	},

	-- Animations (Master Toggle)
	animations = {
		enabled = true,
	},

	-- Master Layout specifics
	master = {
		new_status = "master",
	},

	dwindle = {
		preserve_split = true,
		smart_split = false,
		smart_resizing = false,
	},

	-- Cursor behavior
	cursor = {
		zoom_factor = 1,
		zoom_rigid = false,
		zoom_disable_aa = true,
		hotspot_padding = 1,
		no_hardware_cursors = true,
		enable_hyprcursor = false,
		hide_on_key_press = true,
		no_warps = true,
	},

	-- Miscellaneous
	misc = {
		disable_hyprland_logo = true,
		disable_splash_rendering = true,
		vrr = 2,
		enable_swallow = true,
		swallow_regex = "^(btop|htop|top|nvim|less|man|magic|kitty)$",
		on_focus_under_fullscreen = 2,
		allow_session_lock_restore = true,
		initial_workspace_tracking = false,
		focus_on_activate = true,
	},

	-- Input Devices
	input = {
		kb_layout = "us",
		numlock_by_default = true,
		repeat_delay = 250,
		repeat_rate = 35,

		follow_mouse = 1,
		sensitivity = 0.2,

		touchpad = {
			natural_scroll = true,
			scroll_factor = 0.5,
			disable_while_typing = true,
			clickfinger_behavior = true,
		},
	},

	-- XWayland
	xwayland = {
		force_zero_scaling = true,
	},
})

-- gestures

hl.gesture({
	fingers = 3,
	direction = "swipe",
	action = "move",
})

hl.gesture({
	fingers = 3,
	direction = "pinch",
	action = "fullscreen",
})
hl.gesture({
	fingers = 4,
	direction = "horizontal",
	action = "workspace",
})

-- ==========================================
-- 3. Animations Setup (Hyprland 0.55+ Lua API)
-- ==========================================

-- Define Curves (Beziers)
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1.0 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })
hl.curve("emphasizedDecel", { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 } } })
hl.curve("emphasizedAccel", { type = "bezier", points = { { 0.3, 0 }, { 0.8, 0.15 } } })
hl.curve("standardDecel", { type = "bezier", points = { { 0, 0 }, { 0, 1 } } })
hl.curve("menu_decel", { type = "bezier", points = { { 0.1, 1 }, { 0, 1 } } })
hl.curve("menu_accel", { type = "bezier", points = { { 0.52, 0.03 }, { 0.72, 0.08 } } })
hl.curve("stall", { type = "bezier", points = { { 1, -0.1 }, { 0.7, 0.85 } } })

-- Map Animations
hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "easeOutQuint" })
hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "emphasizedDecel" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 3, bezier = "emphasizedDecel", style = "popin 80%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2, bezier = "emphasizedDecel", style = "popin 90%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 3, bezier = "emphasizedDecel", style = "slide" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 3, bezier = "emphasizedDecel" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 2, bezier = "emphasizedDecel" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.5, bezier = "emphasizedDecel" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 2.7, bezier = "emphasizedDecel", style = "popin 93%" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 2.4, bezier = "menu_accel", style = "popin 94%" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 0.5, bezier = "menu_decel" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 2.7, bezier = "stall" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 7, bezier = "menu_decel", style = "slide" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1.21, bezier = "menu_decel", style = "slide" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "menu_decel", style = "slide" })
hl.animation({ leaf = "specialWorkspaceIn", enabled = true, speed = 2.8, bezier = "emphasizedDecel", style = "slidevert" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 1.2, bezier = "emphasizedAccel", style = "slidevert" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 3, bezier = "standardDecel" })

-- ==========================================
-- 4. Load Post-requisite Modules
-- ==========================================
require("windowrules")
require("binds")
