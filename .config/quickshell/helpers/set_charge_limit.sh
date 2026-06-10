#!/bin/bash
LIMIT="${1:-80}"
BAT=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1)
if [[ -z "$BAT" || ! -f "$BAT/charge_control_end_threshold" ]]; then
    echo "No charge control endpoint found" >&2
    exit 1
fi

current=$(cat "$BAT/charge_control_end_threshold" 2>/dev/null)
if [[ "$current" == "$LIMIT" ]]; then
    exit 0
fi

pkexec sh -c "echo '${LIMIT}' > '${BAT}/charge_control_end_threshold'"
