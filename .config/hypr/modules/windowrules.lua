local dialog_size = {
	"monitor_w*0.50",
	"monitor_h*0.55",
}

local function rule_name(prefix, s)
	return (prefix .. "_" .. s):gsub("[^%w]+", "_")
end

local function float_centered(match, opts)
	opts = opts or {}
	local spec = {
		name = rule_name(
			"float",
			(match.class or "") .. "_" .. (match.title or "") .. "_" .. (match.initial_title or "")
		),
		match = match,
		float = true,
		center = opts.center ~= false,
	}
	if opts.size then
		spec.size = opts.size
	end
	hl.window_rule(spec)
end

hl.window_rule({
	name = "suppress_maximize",
	match = { class = ".*" },
	suppress_event = "maximize",
})

hl.window_rule({
	name = "fix_xwayland_drags",
	match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
	no_focus = true,
})

hl.window_rule({
	name = "no_shadow_tiled",
	match = { float = false },
	no_shadow = true,
	no_blur = true,
})

hl.layer_rule({
	name = "osd_blur",
	match = { namespace = "quickshell-osd" },
	blur = true,
})

hl.layer_rule({
	name = "mako_blur",
	match = { namespace = "mako" },
	blur = true,
	animation = "slide top",
})

hl.layer_rule({
	name = "quickshell_popup_dim",
	match = { namespace = "quickshell-popup" },
	dim_around = true,
})

local dialog_titles = {
	{ re = "^(Open File)(.*)$", size = dialog_size },
	{ re = "^(Select a File)(.*)$", size = dialog_size },
	{ re = "^(Open Folder)(.*)$", size = dialog_size },
	{ re = "^(Save As)(.*)$", size = dialog_size },
	{ re = "^(File Upload)(.*)$", size = dialog_size },
	{ re = "^(Library)(.*)$", size = dialog_size },
	{ re = "^(.*)(wants to save)$", size = dialog_size },
	{ re = "^(.*)(wants to open)$", size = dialog_size },
	{
		re = "^(Choose wallpaper)(.*)$",
		size = { "monitor_w*0.60", "monitor_h*0.65" },
	},
}

for _, d in ipairs(dialog_titles) do
	float_centered({ initial_title = d.re }, { size = d.size })
end

float_centered({ class = "^org\\.freedesktop\\.impl\\.portal\\.desktop\\..*$" }, { size = dialog_size })

float_centered({ initial_title = "^Edit snapshot$" }, { size = { "monitor_w*0.75", "monitor_h*0.80" } })

local sized_floats = {
	{ re = "^(pavucontrol)$", size = { "monitor_w*0.45", "monitor_h*0.45" } },
	{ re = "^(org\\.pulseaudio\\.pavucontrol)$", size = { "monitor_w*0.45", "monitor_h*0.45" } },
	{ re = "^(nm-connection-editor)$", size = { "monitor_w*0.45", "monitor_h*0.45" } },
	{ re = "^(Zotero)$", size = { "monitor_w*0.45", "monitor_h*0.45" } },
}

for _, c in ipairs(sized_floats) do
	float_centered({ class = c.re }, { size = c.size })
end

float_centered({ class = "^(kitty|foot|Alacritty)$", initial_title = "^(impala)$" }, { size = dialog_size })

local floating_classes = {
	"^(blueberry\\.py)$",
	"^(guifetch)$",
	".*plasmawindowed.*",
	"kcm_.*",
	".*bluedevilwizard",
	"^(illogical-impulse Settings)$",
	"^(org\\.quickshell)$",
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

local specific_floats = {
	{ class = "^(org.kde.dolphin)$", title = "^(Progress Dialog — Dolphin)$" },

	-- Firefox
	{ class = "^(firefox)$", title = "^(Library)$" },

	-- Opera / Opera GX
	{ class = "^(Opera GX|Opera)$", title = "^(Library)$" },
}

for _, m in ipairs(specific_floats) do
	hl.window_rule({
		name = rule_name("float", m.class .. "_" .. m.title),
		match = {
			class = m.class,
			title = m.title,
		},
		float = true,
	})
end

hl.window_rule({
	name = "plasma_changeicons",
	match = { class = "^(plasma-changeicons)$" },
	float = true,
	no_initial_focus = true,
	move = { 999999, 999999 },
})

hl.window_rule({
	name = "dolphin_copy_move",
	match = { initial_title = "^(Copying — Dolphin)$" },
	move = { 40, 80 },
})

local pip_regex = "^[Pp]icture[- ]?[Ii]n[- ]?[Pp]icture.*$"

hl.window_rule({
	name = "pip",
	match = {
		title = pip_regex,
	},
	float = true,
	pin = true,
	keep_aspect_ratio = true,
	move = { "monitor_w*0.73", "monitor_h*0.72" },
	size = { "monitor_w*0.25", "monitor_h*0.25" },
})

hl.window_rule({
	name = "screen_sharing",
	match = {
		initial_title = "^.*is sharing (a window|your screen).*$",
	},
	float = true,
	pin = true,
	move = { "monitor_w*0.5-window_w*0.5", "monitor_h-window_h-12" },
})

hl.window_rule({ name = "immediate_steam_app", match = { class = "^(steam_app.*)$" }, immediate = true })
hl.window_rule({ name = "immediate_minecraft", match = { title = "^(.*minecraft.*)$" }, immediate = true })
hl.window_rule({ name = "immediate_exe", match = { title = [[^(.*\.exe.*)$]] }, immediate = true })
