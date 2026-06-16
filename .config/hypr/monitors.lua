local M = {}

-- Monitor identifiers
local INTERNAL = "eDP-1"
local EXTERNAL = "HDMI-A-1"

-- Adjust INTERNAL_SCALE until the internal display feels comfortable
local INTERNAL_SCALE = 1.0
local EXTERNAL_SCALE = 1.0

local function run_cmd(cmd)
  if hl and hl.exec_cmd then
    hl.exec_cmd(cmd)
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
  hl.monitor({
    output = INTERNAL,
    mode = "1920x1080@60.01",
    position = "0x0",
    scale = INTERNAL_SCALE,
  })

  hl.monitor({
    output = EXTERNAL,
    mode = "1920x1080@60.01",
    position = "0x0",
    scale = INTERNAL_SCALE,
    mirror = INTERNAL,
  })

  notify("󰍺", "Mirror Mode")
end

-- 3. Safe Reset
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
    position = "auto",
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
