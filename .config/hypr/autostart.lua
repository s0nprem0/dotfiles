hl.on("hyprland.start", function()
	-- bar + notification daemon (quickshell has built-in NotificationServer)
	hl.exec_cmd("uwsm app -- qs")
	hl.exec_cmd("uwsm app -- hyprpaper")

	-- core components (auth, lockscreen)
	hl.exec_cmd("dbus-update-activation-environment --all")
	hl.exec_cmd("uwsm app -- /usr/lib/hyprpolkitagent/hyprpolkitagent")
	hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
	hl.exec_cmd("uwsm app -- ~/.config/hypr/scripts/usb-monitor.sh")
	hl.exec_cmd("uwsm app -- ~/.config/hypr/scripts/idle-inhibit.sh")
	hl.exec_cmd("uwsm app -- ~/.config/waybar/scripts/battery-notify.sh")

	-- audio
	hl.exec_cmd("uwsm app -- easyeffects --hide-window --service-mode")

	hl.exec_cmd("uwsm app -- hypridle")
	-- clipboard watcher
	hl.exec_cmd("uwsm app -- ~/.config/hypr/scripts/cliphist.sh store")
end)
