hl.on("hyprland.start", function()
	-- bar (quickshell replaces waybar)
	hl.exec_cmd("uwsm app -- qs")
	hl.exec_cmd("uwsm app -- hyprpaper")

	-- core components (auth, lockscreen, notification daemon)
	hl.exec_cmd("dbus-update-activation-environment --all")
	hl.exec_cmd("uwsm app -- /usr/lib/hyprpolkitagent/hyprpolkitagent")
	hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
	hl.exec_cmd("sleep 1 && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
	hl.exec_cmd("uwsm app -- ~/.config/hypr/scripts/usb-monitor.sh")
	hl.exec_cmd("uwsm app -- ~/.config/hypr/scripts/idle-inhibit.sh")
	hl.exec_cmd("uwsm app -- ~/.config/waybar/scripts/battery-notify.sh")

	-- audio
	hl.exec_cmd("uwsm app -- easyeffects --hide-window --service-mode")

	hl.exec_cmd("hyprctl setcursor macos 20")
	hl.exec_cmd("uwsm app -- hypridle")
	-- clipboard watcher
	hl.exec_cmd("uwsm app -- ~/.config/hypr/scripts/cliphist.sh store")

	-- Quickshell window rules (FloatingWindow xdg-toplevel positioning)
	local qsRule = function(name, title, moveX, moveY, width, height)
	  local size = ""
	  if width and height then
	    size = ", size = { " .. width .. ", " .. height .. " }"
	  elseif width then
	    size = ", size = { " .. width .. ", -1 }"
	  end
	  hl.exec_cmd("hyprctl eval 'hl.window_rule({ name = \"" .. name .. "\", match = { class = \"org.quickshell\", title = \"" .. title .. "\" }, float = true, pin = true, move = { \"" .. moveX .. "\", \"" .. moveY .. "\" }" .. size .. ", no_initial_focus = true })'")
	end

	qsRule("qwifi",           "network_popup",       "monitor_w-window_w-12", "40",  "380", "460")
	qsRule("notif_center",    "notification_center",  "monitor_w-window_w-12", "44",  "400", "460")
	qsRule("notif_toast",     "notification_toast",   "monitor_w-window_w-12", "44",  "360", nil)
end)
