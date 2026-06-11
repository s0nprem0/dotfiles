#!/usr/bin/env bash

case "${1:-menu}" in
store)
	wl-paste --type text --watch cliphist store 2>/dev/null &
	wl-paste --type image --watch cliphist store 2>/dev/null &
	;;
menu)
	selection=$(cliphist list | rofi -dmenu -p "󰅍 Clipboard" -theme ~/.config/rofi/base.rasi)
	if [[ -n "$selection" ]]; then
		echo "$selection" | cliphist decode | wl-copy
	fi
	;;
clear)
	cliphist wipe
	notify-send -a "Clipboard" "History cleared"
	;;
esac
