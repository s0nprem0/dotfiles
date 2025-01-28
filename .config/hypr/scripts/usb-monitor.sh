#!/usr/bin/env bash
set -euo pipefail

command -v udisksctl >/dev/null 2>&1 || exit 0
command -v notify-send >/dev/null 2>&1 || exit 0

# Single-instance lock (survives Hyprland reloads; releases on exit)
if [[ -z "${XDG_RUNTIME_DIR:-}" ]]; then
	exit 0
fi

lockdir="$XDG_RUNTIME_DIR/hypr-usb-monitor.lock"
if ! mkdir "$lockdir" 2>/dev/null; then
	exit 0
fi
trap 'rmdir "$lockdir" 2>/dev/null || true' EXIT INT TERM

udisksctl monitor | while IFS= read -r line; do
	case "$line" in
		*"Added"*)
			label=$(printf '%s' "$line" | sed -n 's/.*\(drive_[[:alnum:]_]\+\).*/\1/p')
			notify-send -u low "USB Connected" "${label:-Device added}"
			;;
		*"Removed"*)
			notify-send -u low "USB Disconnected" "Device removed"
			;;
	esac
done
