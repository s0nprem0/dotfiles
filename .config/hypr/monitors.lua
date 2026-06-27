local INTERNAL = "eDP-1"
local EXTERNAL = "HDMI-A-1"

hl.monitor({
	output = INTERNAL,
	mode = "preferred",
	position = "auto",
	scale = 1.25,
})

hl.monitor({
	output = EXTERNAL,
	mode = "preferred",
	position = "auto-right",
	scale = 1.0,
})

hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = 1,
})
