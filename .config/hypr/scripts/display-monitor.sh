#!/bin/bash
set -euo pipefail

STATE_FILE="${HOME}/.cache/hypr/display_state"
LAST_MODE_FILE="${HOME}/.cache/hypr/last_display_mode"

detect_external() {
	hyprctl monitors -j 2>/dev/null | jq -e '.[] | select(.name == "HDMI-A-1" and .disabled == false)' >/dev/null 2>&1
}

get_current_mode() {
	if [[ -f "$LAST_MODE_FILE" ]]; then
		cat "$LAST_MODE_FILE"
	else
		echo "extend"
	fi
}

set_mode() {
	local mode="$1"
	echo "$mode" > "$LAST_MODE_FILE"
	
	case "$mode" in
		external)
			hyprctl keyword monitor eDP-1 disabled true
			hyprctl keyword monitor HDMI-A-1 disabled false
			;;
		extend)
			hyprctl keyword monitor eDP-1 disabled false
			hyprctl keyword monitor HDMI-A-1 disabled false
			;;
	esac
	
	notify-send -t 1000 "Display: $mode"
}

cycle_mode() {
	local current
	current=$(get_current_mode)
	
	case "$current" in
		extend) echo "duplicate" ;;
		duplicate) echo "external" ;;
		external) echo "internal" ;;
		internal) echo "extend" ;;
		*) echo "extend" ;;
	esac
}

while true; do
	if detect_external; then
		if [[ ! -f "$STATE_FILE" ]]; then
			echo "external_connected" > "$STATE_FILE"
		fi
	else
		if [[ -f "$STATE_FILE" ]]; then
			rm -f "$STATE_FILE"
			set_mode "$(cycle_mode)"
		fi
	fi
	sleep 2
done