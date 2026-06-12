#!/bin/bash
set -euo pipefail

LIMIT="${1:-80}"
if ! [[ "$LIMIT" =~ ^[0-9]+$ ]] || [ "$LIMIT" -lt 1 ] || [ "$LIMIT" -gt 100 ]; then
  echo "Error: LIMIT must be an integer between 1 and 100" >&2
  exit 1
fi

BAT=$(find /sys/class/power_supply -name 'BAT*' -type d 2>/dev/null | head -1)
if [[ -z "$BAT" || ! -f "$BAT/charge_control_end_threshold" ]]; then
  echo "No charge control endpoint found for battery" >&2
  exit 1
fi

current=$(cat "$BAT/charge_control_end_threshold" 2>/dev/null || echo 0)
if [[ "$current" == "$LIMIT" ]]; then
  exit 0
fi

pkexec sh -c "echo '${LIMIT}' > '${BAT}/charge_control_end_threshold'" || {
  echo "Failed to set charge threshold (pkexec may have been denied)" >&2
  exit 1
}
