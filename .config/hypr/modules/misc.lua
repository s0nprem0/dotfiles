hl.config({
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

	xwayland = {
		force_zero_scaling = true,
	},
})
