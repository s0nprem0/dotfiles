hl.workspace_rule({ workspace = "1", monitor = "eDP-1", default = true })
hl.workspace_rule({ workspace = "2", monitor = "HDMI-A-1" })
hl.workspace_rule({ workspace = "3", monitor = "HDMI-A-1" })
hl.workspace_rule({ workspace = "4", monitor = "HDMI-A-1" })

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
