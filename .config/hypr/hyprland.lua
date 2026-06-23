local function safe_require(mod)
  local ok, err = pcall(require, mod)
  if not ok then
    local msg = tostring(err):gsub("'", "'\\''")
    os.execute("notify-send -u critical 'Hyprland Error' '" .. mod .. ": " .. msg .. "'")
  end
  return ok
end

pcall(require, "monitors")
safe_require("modules.presentation")
safe_require("modules.defaultPrograms")

local colors_ok = pcall(dofile, os.getenv("HOME") .. "/.config/hypr/colors.lua")
if not colors_ok then
  accent = "b8c3ff"
  surface = "121318"
  on_surface = "e3e1e9"
  error_hex = "ffb4ab"
end

safe_require("modules.env")
safe_require("modules.misc")
safe_require("modules.decorations")
safe_require("modules.layout")
safe_require("modules.workspace")
safe_require("modules.autostart")
safe_require("modules.windowrules")
safe_require("modules.binds")
