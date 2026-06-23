local M = {}

local monitors = require("monitors")

local INTERNAL = "eDP-1"
local EXTERNAL = "HDMI-A-1"
local INTERNAL_SCALE = 1.0
local EXTERNAL_SCALE = 1.0

local PRESENTATION_STATE_FILE = os.getenv("HOME") .. "/.cache/hypr/presentation_state"

local function read_state()
	local file = io.open(PRESENTATION_STATE_FILE, "r")
	if file then
		local state = file:read("*all")
		file:close()
		return state:match("^(%w+)$")
	end
	return nil
end

local function write_state(state)
	local file = io.open(PRESENTATION_STATE_FILE, "w")
	if file then
		file:write(state or "")
		file:close()
	end
end

local function inhibit_notifications(inhibit)
	local cmd
	if inhibit then
		cmd = "hyprctl keyword general:disable_scratchpad_spawn_rules true 2>/dev/null || true"
	else
		cmd = "hyprctl keyword general:disable_scratchpad_spawn_rules false 2>/dev/null || true"
	end
	os.execute(cmd)
end

function M.enter_presentation()
	monitors.set_external()
	inhibit_notifications(true)
	write_state("presentation")
end

function M.enter_presenter_view()
	hl.monitor({
		output = INTERNAL,
		mode = "preferred",
		position = "0x0",
		scale = INTERNAL_SCALE,
	})
	hl.monitor({
		output = EXTERNAL,
		mode = "preferred",
		position = "auto-right",
		scale = EXTERNAL_SCALE,
	})
	local ok, monitors_list = pcall(hl.get_monitors)
	if ok and monitors_list then
		for _, m in ipairs(monitors_list) do
			if m.name == EXTERNAL then
				hl.workspace_rule({ workspace = tostring(m.activeWorkspace.id or 1), monitor = EXTERNAL })
			end
		end
	end
	inhibit_notifications(false)
	write_state("presenter")
end

function M.exit_presentation()
	local last_mode = read_state() or "extend"
	if last_mode == "presentation" then
		monitors.set_extend()
	else
		monitors.set_extend()
	end
	inhibit_notifications(false)
	write_state(nil)
end

function M.toggle_presentation()
	local current = monitors.get_current_mode()
	if current == "external" then
		M.exit_presentation()
	else
		M.enter_presentation()
	end
end

function M.is_presenting()
	return read_state() == "presentation"
end

return M