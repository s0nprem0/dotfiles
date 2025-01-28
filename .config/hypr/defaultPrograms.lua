-- ###################
-- ### MY PROGRAMS ###
-- ###################

-- See https://wiki.hyprland.org/Configuring/Keywords/

-- Set programs that you use
-- Defining these without 'local' makes them globally available to other modules
terminal = "uwsm app -- kitty"
fileManager = "uwsm app -- thunar"
menu = "uwsm app -- rofi -show drun"
browser = "firefox"

-- In Lua, we use '..' to concatenate strings
gemini = browser .. " --new-window https://gemini.google.com/app"
chatgpt = browser .. " --new-window https://chat.openai.com/"
