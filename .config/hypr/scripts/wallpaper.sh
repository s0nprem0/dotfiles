#!/usr/bin/env bash
set -uo pipefail

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

# Step 2: Apply theme_switcher to update app-specific themes
if command -v theme_switcher &>/dev/null; then
  theme_switcher "$WALLPAPER" || echo "Warning: theme_switcher failed"
else
  echo "theme_switcher not found in PATH"
fi

# Step 3: Set wallpaper on all monitors
for MONITOR in $(hyprctl -j monitors | jq -r '.[].name'); do
  hyprctl hyprpaper wallpaper "$MONITOR,$WALLPAPER"
done

# Persist wallpaper path in configs
sed -i "s|^    path = .*|    path = $WALLPAPER|" "$HOME/.config/hypr/hyprpaper.conf"
sed -i "s|^    path = .*|    path = $WALLPAPER|" "$HOME/.config/hypr/hyprlock.conf"

# Persist wallpaper path for theme tab
mkdir -p "$HOME/.cache/quickshell"
realpath "$WALLPAPER" > "$HOME/.cache/quickshell/current_wallpaper"

echo "Wallpaper and colors updated!"
