#!/usr/bin/env bash
set -euo pipefail

PRESET_DIR="${1:-$HOME/.config/matugen/presets}"

if [[ ! -d "$PRESET_DIR" ]]; then
  echo '{"presets":[]}'
  exit 0
fi

echo -n '{"presets":['
first=true
for f in "$PRESET_DIR"/*.json; do
  [[ -f "$f" ]] || continue
  $first || echo -n ','
  first=false
  name=$(jq -r '.name // "unknown"' "$f" 2>/dev/null)
  variant=$(jq -r '.variant // "dark"' "$f" 2>/dev/null)
  primary=$(jq -r '.shell.primary // "#ffffff"' "$f" 2>/dev/null)
  printf '{"file":"%s","name":"%s","variant":"%s","primary":"%s"}' "$f" "$name" "$variant" "$primary"
done
echo ']}'
