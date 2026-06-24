#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $(basename "$0") <lock|sleep|reboot|poweroff|logout>"
    exit 1
}

action="${1:-}"
[[ -z "$action" ]] && usage

case "$action" in
    lock)
        hyprlock
        ;;
    sleep)
        systemctl suspend
        ;;
    reboot)
        systemctl reboot
        ;;
    poweroff)
        systemctl poweroff
        ;;
    logout)
        if command -v uwsm >/dev/null 2>&1 && uwsm check; then
            uwsm stop
        else
            hyprctl dispatch exit || pkill -x Hyprland
        fi
        ;;
    *)
        usage
        ;;
esac
