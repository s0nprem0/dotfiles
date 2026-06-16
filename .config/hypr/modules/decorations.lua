hl.config({
	decoration = {
		active_opacity = 1,
		inactive_opacity = 1,
		rounding = 2,

		blur = {
			enabled = true,
			size = 4,
			passes = 2,
			contrast = 1.5,
			brightness = 0.8,
			ignore_opacity = true,
			new_optimizations = true,
		},

		shadow = {
			enabled = false,
			range = 3,
			render_power = 2,
		},

		dim_inactive = true,
		dim_strength = 0.05,
		dim_special = 0.2,
	},
})
