-- ======================
-- Opacity Rules
-- ======================

local function rule_name(prefix, s)
	-- Names are identifiers; avoid spaces/regex chars that can make rules fail to register.
	return (prefix .. "_" .. s):gsub("[^%w]+", "_")
end

-- Grouping classes by their desired opacity keeps the config incredibly clean (DRY)
local opacity_map = {
	["0.90 0.90"] = {
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
		"^(io.github.flattool.Warehouse)$",
	},
	["0.95 0.95"] = {
		"^(code-oss)$",
		"^(Spotify)$",
	},
	["0.90 0.70"] = {
		"^(org.pulseaudio.pavucontrol)$",
		"^(blueman-manager)$",
		"^(nm-applet)$",
		"^(nm-connection-editor)$",
		"^(org.kde.polkit-kde-authentication-agent-1)$",
		"^(polkit-gnome-authentication-agent-1)$",
		"^(org.freedesktop.impl.portal.desktop.gtk)$",
		"^(org.freedesktop.impl.portal.desktop.hyprland)$",
	},
	["0.70 0.70"] = {
		"^([Ss]team)$",
		"^(steamwebhelper)$",
	},
}

-- Loop through the map and apply the rules dynamically
for opacity, classes in pairs(opacity_map) do
	for _, class in ipairs(classes) do
		hl.window_rule({
			name = rule_name("opacity", opacity .. "_" .. class),
			match = { class = class },
			opacity = opacity,
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

-- Common dialogs (match by *initial* title; rules are evaluated top-to-bottom)
local floating_dialog_titles = {
	"^(Open File)(.*)$",
	"^(Select a File)(.*)$",
	"^(Choose wallpaper)(.*)$",
	"^(Open Folder)(.*)$",
	"^(Save As)(.*)$",
	"^(Library)(.*)$",
	"^(File Upload)(.*)$",
	"^(.*)(wants to save)$",
	"^(.*)(wants to open)$",
}

for _, title in ipairs(floating_dialog_titles) do
	local spec = {
		name = rule_name("float_dialog", title),
		match = { title = title },
		float = true,
		center = true,
	}
	if title == "^(Choose wallpaper)(.*)$" then
		spec.size = { "monitor_w*0.60", "monitor_h*0.65" }
	end
	hl.window_rule(spec)
end

-- App-specific floating rules with sizing
local floating_sized_classes = {
	["^(pavucontrol)$"] = { "monitor_w*0.45", "monitor_h*0.45" },
	["^(org.pulseaudio.pavucontrol)$"] = { "monitor_w*0.45", "monitor_h*0.45" },
	["^(nm-connection-editor)$"] = { "monitor_w*0.45", "monitor_h*0.45" },
	["org.freedesktop.impl.portal.desktop.kde"] = { "monitor_w*0.60", "monitor_h*0.65" },
	["^(Zotero)$"] = { "monitor_w*0.45", "monitor_h*0.45" },
}

for class, size in pairs(floating_sized_classes) do
	hl.window_rule({
		name = rule_name("float_sized", class),
		match = { class = class },
		float = true,
		center = true,
		size = size,
	})
end

local floating_classes = {
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
	{ class = "^(org.kde.dolphin)$", title = "^(Copying — Dolphin)$" },
	{ class = "^(firefox)$", title = "^(Picture-in-Picture)$" },
	{ class = "^(firefox)$", title = "^(Library)$" },
	{ class = "^(kitty)$", title = "^(top)$" },
	{ class = "^(kitty)$", title = "^(btop)$" },
	{ class = "^(kitty)$", title = "^(htop)$" },
}

for _, match in ipairs(specific_floats) do
	hl.window_rule({
		name = rule_name("float", match.class .. "_" .. match.title),
		match = { class = match.class, title = match.title },
		float = true,
	})
end

-- ======================
-- Picture-in-Picture
-- ======================
-- Note: Using [[ ]] for the string instead of " " prevents us from having to manually escape all the regex backslashes!
local pip_regex = [[^([Pp]icture[-\s]?[Ii]n[-\s]?[Pp]icture)(.*)$]]

local pip_rules = {
	"float",
	"pin",
	-- keepaspectratio is a hyprlang windowrule; the current Lua window_rule helper
	-- doesn't support it, so keep this in windowrules.conf if you need it.
	"move 100%-w-20 100%-h-20",
	"opacity 1.0 1.0",
}

for _, rule in ipairs(pip_rules) do
	local spec = {
		name = rule_name("pip", rule),
		match = { title = pip_regex },
	}
	if rule == "float" then
		spec.float = true
	elseif rule == "pin" then
		spec.pin = true
	elseif rule:match("^move ") then
		spec.move = rule:gsub("^move ", "")
	elseif rule:match("^opacity ") then
		spec.opacity = rule:gsub("^opacity ", "")
	end
	hl.window_rule(spec)
end

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
