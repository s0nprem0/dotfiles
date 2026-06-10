-- ==========================================
-- 1. Load Pre-requisite Modules
-- ==========================================
require("monitors")
require("defaultPrograms")

dofile(os.getenv("HOME") .. "/.config/matugen/output/hypr-colors.lua")

-- Environment should be set before we start any long-running processes.
require("env")

-- Workspace placement
hl.workspace_rule({ workspace = "1", monitor = "eDP-1", default = true })

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
		inactive_opacity = 0.85,
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

-- (Optional) Example of defining a Spring curve if you prefer Apple-like bouncy movement
-- hl.curve("mySpring", { type = "spring", mass = 1, stiffness = 50, dampening = 10 })

-- Map Animations (Using the strict `bezier = "name"` key instead of `curve = "name"`)
hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "easeOutQuint" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })

-- ==========================================
-- 4. Load Post-requisite Modules
-- ==========================================
require("windowrules")
require("binds")
