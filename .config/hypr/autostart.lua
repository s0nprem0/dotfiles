hl.on("hyprland.start", function()
	-- bar, wallpaper
	hl.exec_cmd("uwsm app -- waybar")
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
	hl.exec_cmd("uwsm app -- swaync")

	-- clipboard watcher
	hl.exec_cmd("uwsm app -- ~/.config/hypr/scripts/cliphist.sh store")
end)
