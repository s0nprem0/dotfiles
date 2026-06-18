#!/usr/bin/env bash

case "${1:-menu}" in
store)
	wl-paste --type text --watch cliphist store 2>/dev/null &
	wl-paste --type image --watch cliphist store 2>/dev/null &
	;;
menu)
	selection=$(cliphist list | fzf --prompt="󰅍 Clipboard > " --height=40% --layout=reverse --bind=enter:accept)
	if [[ -n "$selection" ]]; then
		echo "$selection" | cliphist decode | wl-copy
	fi
	;;
clear)
	cliphist wipe
	notify-send -a "Clipboard" "History cleared"
	;;
esac
