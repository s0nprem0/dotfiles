local M = {}

-- Monitor identifiers
local INTERNAL = "eDP-1"
local EXTERNAL = "HDMI-A-1"

-- Adjust INTERNAL_SCALE until the internal display feels comfortable
local INTERNAL_SCALE = 1.25
local EXTERNAL_SCALE = 1.0

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

-- 1. Extended Layout (Recommended daily use)
function M.set_extended()
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

  notify("󰍹", "Extended Workspace")
end

-- 2. Mirror / Clone Layout
function M.set_mirror()
  local internal_mode = "preferred"
  local ok, monitors = pcall(hl.get_monitors)
  if ok and monitors then
    for _, m in ipairs(monitors) do
      if m.name == INTERNAL then
        local rate = m.refreshRate or m.refresh_rate or 60
        internal_mode = string.format("%dx%d@%.2f", m.width, m.height, rate)
        break
      end
    end
  end

  hl.monitor({
    output = INTERNAL,
    mode = internal_mode,
    position = "0x0",
    scale = INTERNAL_SCALE,
  })

  hl.monitor({
    output = EXTERNAL,
    mode = internal_mode,
    position = "0x0",
    scale = INTERNAL_SCALE,
    mirror = INTERNAL,
  })

  notify("󰍺", "Mirror Mode")
end

-- 3. Internal Only (laptop on the go)
function M.set_internal_only()
  hl.monitor({
    output = INTERNAL,
    mode = "preferred",
    position = "0x0",
    scale = INTERNAL_SCALE,
  })

  hl.monitor({
    output = EXTERNAL,
    disabled = true,
  })

  notify("󰍹", "Internal Only")
end

-- 4. External Only (docked, lid closed)
function M.set_external_only()
  hl.monitor({
    output = INTERNAL,
    disabled = true,
  })

  hl.monitor({
    output = EXTERNAL,
    mode = "preferred",
    position = "0x0",
    scale = EXTERNAL_SCALE,
  })

  notify("󰍹", "External Only")
end

-- 5. Safe Reset (matches boot defaults)
function M.reset()
  hl.monitor({
    output = INTERNAL,
    mode = "preferred",
    position = "auto",
    scale = INTERNAL_SCALE,
  })

  hl.monitor({
    output = EXTERNAL,
    mode = "preferred",
    position = "auto-right",
    scale = EXTERNAL_SCALE,
  })

  notify("Display Manager", "Monitors reset to defaults")
end

-- Default configuration applied when this file is loaded
hl.monitor({
  output = INTERNAL,
  mode = "preferred",
  position = "auto",
  scale = INTERNAL_SCALE,
})

hl.monitor({
  output = EXTERNAL,
  mode = "preferred",
  position = "auto-right",
  scale = EXTERNAL_SCALE,
})

-- Fallback rule for any other monitors
hl.monitor({
  output = "",
  mode = "preferred",
  position = "auto",
  scale = 1,
})

return M
