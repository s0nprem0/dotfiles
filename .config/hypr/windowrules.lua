-- ======================
-- Opacity Rules
-- ======================

local function rule_name(prefix, s)
	-- Names are identifiers; avoid spaces/regex chars that can make rules fail to register.
	return (prefix .. "_" .. s):gsub("[^%w]+", "_")
end

-- Keep ordering deterministic (rules are evaluated top-to-bottom).
local opacity_rules = {
	{
		opacity = "0.90 0.90",
		classes = {
			"^(chromium)$",
			"^(Brave-browser)$",
			"^(zen-browser)$",
			"^(Code)$",
			"^(code-url-handler)$",
			"^(code-insiders-url-handler)$",
			"^(kitty)$",
			"^(org.kde.dolphin)$",
			"^(org.kde.ark)$",
			"^(nwg-look)$",
			"^(qt5ct)$",
			"^(qt6ct)$",
			"^(kvantummanager)$",
			"^(com.github.rafostar.Clapper)$",
			"^(com.github.tchx84.Flatseal)$",
			"^(hu.kramo.Cartridges)$",
			"^(com.obsproject.Studio)$",
			"^(gnome-boxes)$",
			"^(discord)$",
			"^(WebCord)$",
			"^(ArmCord)$",
			"^(app.drey.Warp)$",
			"^(net.davidotek.pupgui2)$",
			"^(yad)$",
			"^(Signal)$",
			"^(io.github.alainm23.planify)$",
			"^(io.gitlab.theevilskeleton.Upscaler)$",
			"^(com.github.unrud.VideoDownloader)$",
			"^(io.gitlab.adhami3310.Impression)$",
	"^(io.missioncenter.MissionCenter)$",
	"^(com.usebottles.bottles)$",
			"^(io.github.flattool.Warehouse)$",
		},
	},
	{ opacity = "0.95 0.95", classes = { "^(code-oss)$", "^(Spotify)$", "^(com\\.usebottles\\.bottles)$" } },
	{
		opacity = "0.90 0.70",
		classes = {
			"^(org.pulseaudio.pavucontrol)$",
			"^(blueman-manager)$",
			"^(nm-applet)$",
			"^(nm-connection-editor)$",
			"^(org.kde.polkit-kde-authentication-agent-1)$",
			"^(polkit-gnome-authentication-agent-1)$",
			"^(org.freedesktop.impl.portal.desktop.gtk)$",
			"^(org.freedesktop.impl.portal.desktop.hyprland)$",
		},
	},
	{ opacity = "0.70 0.70", classes = { "^([Ss]team)$", "^(steamwebhelper)$" } },
}

for _, rule in ipairs(opacity_rules) do
	for _, class in ipairs(rule.classes) do
		hl.window_rule({
			name = rule_name("opacity", rule.opacity .. "_" .. class),
			match = { class = class },
			opacity = rule.opacity,
		})
	end
end

-- Specific Initial Title match for Spotify Free
hl.window_rule({
	name = "opacity_spotify_free",
	match = { initial_title = "^(Spotify Free)$" },
	opacity = "0.70 0.70",
})

-- ======================
-- Floating Rules
-- ======================

-- If you enable blur later, this prevents blur on empty-class XWayland context menus.
-- (This is the same match used in the stock example config.)
hl.window_rule({
	name = "no_blur_xwayland_menus",
	match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
	no_blur = true,
	no_focus = true,
})

local function float_centered(match, opts)
	opts = opts or {}
	local spec = {
		name = rule_name("float", (match.class or "") .. "_" .. (match.title or "") .. "_" .. (match.initial_title or "")),
		match = match,
		float = true,
		center = (opts.center ~= false),
	}
	if opts.size then
		spec.size = opts.size
	end
	hl.window_rule(spec)
end

-- Common dialogs by *initial* title. Static rules only evaluate at window creation.
local floating_dialog_titles = {
	-- File pickers / dialogs
	{ re = "^(Open File)(.*)$" },
	{ re = "^(Select a File)(.*)$" },
	{ re = "^(Open Folder)(.*)$" },
	{ re = "^(Save As)(.*)$" },
	{ re = "^(File Upload)(.*)$" },
	{ re = "^(Library)(.*)$" },
	{ re = "^(.*)(wants to save)$" },
	{ re = "^(.*)(wants to open)$" },
	-- Custom dialogs
	{ re = "^(Choose wallpaper)(.*)$", size = { "monitor_w*0.60", "monitor_h*0.65" } },
}

for _, d in ipairs(floating_dialog_titles) do
	float_centered({ initial_title = d.re }, { size = d.size })
end

-- Portals (file pickers etc.)
float_centered({ class = "^org\\.freedesktop\\.impl\\.portal\\.desktop\\..*$" }, { size = { "monitor_w*0.60", "monitor_h*0.65" } })

-- App-specific floating rules with sizing
local floating_sized_classes = {
	{ re = "^(pavucontrol)$", size = { "monitor_w*0.45", "monitor_h*0.45" } },
	{ re = "^(org\\.pulseaudio\\.pavucontrol)$", size = { "monitor_w*0.45", "monitor_h*0.45" } },
	{ re = "^(nm-connection-editor)$", size = { "monitor_w*0.45", "monitor_h*0.45" } },
	{ re = "^(Zotero)$", size = { "monitor_w*0.45", "monitor_h*0.45" } },
}

for _, c in ipairs(floating_sized_classes) do
	float_centered({ class = c.re }, { size = c.size })
end

-- "plasma-changeicons" helper window: keep it out of the way.
hl.window_rule({
	name = "plasma_changeicons",
	match = { class = "^(plasma-changeicons)$" },
	float = true,
	no_initial_focus = true,
	move = { 999999, 999999 },
})

-- Dolphin copy progress placement
hl.window_rule({
	name = "dolphin_copy_move",
	match = { initial_title = "^(Copying — Dolphin)$" },
	move = { 40, 80 },
})

-- Ensure Warp opens tiled (not floating)
hl.window_rule({
	name = "warp_tile",
	match = { class = "^dev\\.warp\\.Warp$" },
	tile = true,
})

local floating_classes = {
	-- Your extras
	"^(blueberry\\.py)$",
	"^(guifetch)$",
	".*plasmawindowed.*",
	"kcm_.*",
	".*bluedevilwizard",
	"^(illogical-impulse Settings)$",

	"^(vlc)$",
	"^(kvantummanager)$",
	"^(qt5ct)$",
	"^(qt6ct)$",
	"^(nwg-look)$",
	"^(org.kde.ark)$",
	"^(blueman-manager)$",
	"^(nm-applet)$",
	"^(org.kde.polkit-kde-authentication-agent-1)$",
	"^(Signal)$",
	"^(com.github.rafostar.Clapper)$",
	"^(app.drey.Warp)$",
	"^(net.davidotek.pupgui2)$",
	"^(yad)$",
	"^(eog)$",
	"^(io.github.alainm23.planify)$",
	"^(io.gitlab.theevilskeleton.Upscaler)$",
	"^(com.github.unrud.VideoDownloader)$",
	"^(io.gitlab.adhami3310.Impression)$",
	"^(io.missioncenter.MissionCenter)$",
	"^(com.usebottles.bottles)$",
	"^(gnome-calculator)$",
	"^(org.gnome.Calculator)$",
}

for _, class in ipairs(floating_classes) do
	hl.window_rule({
		name = rule_name("float", class),
		match = { class = class },
		float = true,
	})
end

-- Rules that require BOTH a class and a title match
local specific_floats = {
	{ class = "^(org.kde.dolphin)$", title = "^(Progress Dialog — Dolphin)$" },
	{ class = "^(firefox)$", title = "^(Picture-in-Picture)$" },
	{ class = "^(firefox)$", title = "^(Library)$" },
	{ class = "^(kitty)$", title = "^(top)$" },
	{ class = "^(kitty)$", title = "^(btop)$" },
	{ class = "^(kitty)$", title = "^(htop)$" },
}

for _, match in ipairs(specific_floats) do
	hl.window_rule({
		name = rule_name("float", match.class .. "_" .. match.title),
		match = { class = match.class, initial_title = match.title },
		float = true,
	})
end

-- ======================
-- Picture-in-Picture
-- ======================
-- Note: Using [[ ]] for the string instead of " " prevents us from having to manually escape all the regex backslashes!
local pip_regex = [[^([Pp]icture[-\s]?[Ii]n[-\s]?[Pp]icture)(.*)$]]

-- Prefer a single rule per match to keep ordering simple.
hl.window_rule({
	name = "pip",
	match = { initial_title = pip_regex },
	float = true,
	pin = true,
	keep_aspect_ratio = true,
	move = { "monitor_w*0.73", "monitor_h*0.72" },
	size = { "monitor_w*0.25", "monitor_h*0.25" },
})

-- Screen sharing popups: float + pin + place at bottom center.
hl.window_rule({
	name = "screen_sharing",
	match = { initial_title = ".*is sharing (a window|your screen).*" },
	float = true,
	pin = true,
	move = { "monitor_w*0.5-window_w*0.5", "monitor_h-window_h-12" },
})

-- ======================
-- Tearing / Immediate
-- ======================

hl.window_rule({
	name = "immediate_steam_app",
	match = { class = "^(steam_app.*)$" },
	immediate = true,
})
hl.window_rule({
	name = "immediate_minecraft",
	match = { title = "^(.*minecraft.*)$" },
	immediate = true,
})
hl.window_rule({
	name = "immediate_exe",
	match = { title = [[^(.*\.exe.*)$]] },
	immediate = true,
})

-- No shadow for tiled windows
hl.window_rule({
	name = "no_shadow_tiled",
	match = { float = false },
	no_shadow = true,
})

-- ======================
-- Size Rules
-- ======================

-- Terminal windows get reasonable default size
hl.window_rule({
	name = "size_terminal",
	match = { class = "^(kitty)$" },
	size = { "monitor_w*0.45", "monitor_h*0.65" },
})


