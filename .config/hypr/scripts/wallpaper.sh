#!/usr/bin/env bash
set -euo pipefail

WALLPAPER="${1:-}"
if [[ -z "$WALLPAPER" ]]; then
  echo "Usage: $0 <path-to-wallpaper>"
  exit 1
fi

if [[ ! -f "$WALLPAPER" ]]; then
  echo "Error: $WALLPAPER not found"
  exit 1
fi

# Step 1: Generate all colors via matugen templates
matugen image "$WALLPAPER" --prefer darkness -q

# Step 2: Set wallpaper on all monitors
for MONITOR in $(hyprctl -j monitors | jq -r '.[].name'); do
  hyprctl hyprpaper wallpaper "$MONITOR,$WALLPAPER"
done

# Persist wallpaper path in configs
sed -i "s|^    path = .*|    path = $WALLPAPER|" "$HOME/.config/hypr/hyprpaper.conf"
sed -i "s|^    path = .*|    path = $WALLPAPER|" "$HOME/.config/hypr/hyprlock.conf"

# Persist wallpaper path for theme tab
mkdir -p "$HOME/.cache/quickshell"
realpath "$WALLPAPER" > "$HOME/.cache/quickshell/current_wallpaper"

# Step 3: Reload services (if any needed)

echo "Wallpaper and colors updated!"
