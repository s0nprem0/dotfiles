local M = {}

local INTERNAL = "eDP-1"
local EXTERNAL = "HDMI-A-1"

local function run_cmd(cmd)
	if hl and hl.dsp and hl.dsp.exec_cmd then
		hl.dsp.exec_cmd(cmd)
	else
		os.execute(cmd .. " &")
	end
end

local function notify(icon, message)
	run_cmd(string.format("notify-send -t 2000 -a 'Display Manager' '%s' '%s'", icon, message))
end

local function get_monitor_state(output)
	local ok, monitors = pcall(hl.get_monitors)
	if ok and monitors then
		for _, m in ipairs(monitors) do
			if m.name == output then
				return m
			end
		end
	end
	return nil
end

local function has_external()
	local m = get_monitor_state(EXTERNAL)
	return m ~= nil and not m.disabled
end

local function has_internal()
	local m = get_monitor_state(INTERNAL)
	return m ~= nil and not m.disabled
end

function M.set_duplicate()
	if not has_external() then
		notify("󰏥", "No external display")
		return
	end

	local internal_mode = "preferred"
	local m = get_monitor_state(INTERNAL)
	if m then
		local rate = m.refreshRate or m.refresh_rate or 60
		internal_mode = string.format("%dx%d@%.2f", m.width, m.height, rate)
	end

	hl.monitor({
		output = INTERNAL,
		mode = internal_mode,
		position = "0x0",
		scale = 1.0,
	})

	hl.monitor({
		output = EXTERNAL,
		mode = internal_mode,
		position = "0x0",
		scale = 1.0,
		mirror = INTERNAL,
	})

	notify("󰍺", "Duplicate Mode")
end

function M.set_extend()
	local ok, monitors = pcall(hl.get_monitors)
	local has_ext = false
	if ok and monitors then
		for _, m in ipairs(monitors) do
			if m.name == EXTERNAL and not m.disabled then
				has_ext = true
				break
			end
		end
	end

	if has_ext then
		hl.monitor({
			output = INTERNAL,
			mode = "preferred",
			position = "auto",
			scale = 1.0,
		})

		hl.monitor({
			output = EXTERNAL,
			mode = "preferred",
			position = "auto-right",
			scale = 1.0,
		})
		notify("󰍹", "Extend Mode")
	else
		hl.monitor({
			output = INTERNAL,
			mode = "preferred",
			position = "auto",
			scale = 1.0,
		})
		notify("󰍹", "Extend Mode (internal only)")
	end
end

function M.set_internal()
	hl.monitor({
		output = INTERNAL,
		mode = "preferred",
		position = "auto",
		scale = 1.0,
	})

	hl.monitor({
		output = EXTERNAL,
		disabled = true,
	})

	notify("󰍹", "Internal Display Only")
end

function M.set_external()
	if not has_external() then
		notify("󰏥", "No external display")
		return
	end

	hl.monitor({
		output = INTERNAL,
		disabled = true,
	})

	hl.monitor({
		output = EXTERNAL,
		mode = "preferred",
		position = "auto",
		scale = 1.0,
	})

	notify("󰍾", "Presentation Mode")
end

function M.get_current_mode()
	local internal_on = has_internal()
	local external_on = has_external()
	
	if not internal_on and external_on then
		return "external"
	elseif internal_on and external_on then
		local m = get_monitor_state(EXTERNAL)
		if m and m.mirror == INTERNAL then
			return "duplicate"
		end
		return "extend"
	elseif internal_on and not external_on then
		return "internal"
	end
	return "extend"
end

function M.toggle()
	local current = M.get_current_mode()
	local next_mode

	if current == "extend" then
		if has_external() then
			next_mode = "duplicate"
		else
			next_mode = "internal"
		end
	elseif current == "duplicate" then
		next_mode = "external"
	elseif current == "external" then
		next_mode = "internal"
	else
		next_mode = "extend"
	end

	if next_mode == "duplicate" and not has_external() then
		next_mode = "internal"
	end

	if next_mode == "external" and not has_external() then
		next_mode = "internal"
	end

	if next_mode == "duplicate" then
		M.set_duplicate()
	elseif next_mode == "extend" then
		M.set_extend()
	elseif next_mode == "internal" then
		M.set_internal()
	elseif next_mode == "external" then
		M.set_external()
	end
end

hl.monitor({
	output = INTERNAL,
	mode = "preferred",
	position = "auto",
	scale = 1.0,
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

return M