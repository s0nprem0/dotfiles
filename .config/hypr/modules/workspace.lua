hl.workspace_rule({ workspace = "1", monitor = "eDP-1", default = true })

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
