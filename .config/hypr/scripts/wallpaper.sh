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

# Step 1: Run matugen to generate all color templates
matugen image "$WALLPAPER" --prefer darkness -q

# Step 2: Set wallpaper via hyprpaper
hyprctl hyprpaper wallpaper "eDP-1,$WALLPAPER" 2>/dev/null || true
sed -i "s|^path = .*|path = $WALLPAPER|" "$HOME/.config/hypr/hyprpaper.conf"

# Step 3: Update hyprlock wallpaper and colors
sed -i "s|^    path = .*|    path = $WALLPAPER|" "$HOME/.config/hypr/hyprlock.conf"
HYPRLOCK_COLORS="$HOME/.config/hypr/colors-hyprlock.conf"
if [[ -f "$HYPRLOCK_COLORS" ]]; then
  source "$HYPRLOCK_COLORS"
  sed -i "s|^    color = rgba.*|    color = $time_color|" "$HOME/.config/hypr/hyprlock.conf"
  sed -i "s|^    inner_color = rgba.*|    inner_color = $input_inner|" "$HOME/.config/hypr/hyprlock.conf"
  sed -i "s|^    font_color = rgb.*|    font_color = $input_font|" "$HOME/.config/hypr/hyprlock.conf"
  sed -i "s|placeholder_text = .*|placeholder_text = <i><span foreground=\"$placeholder_color\">🔒  Enter Pass</span></i>|" "$HOME/.config/hypr/hyprlock.conf"
fi

# Step 4: Restart services
pkill -SIGUSR2 waybar 2>/dev/null || true
pkill swaync 2>/dev/null; sleep 0.2; swaync &>/dev/null &

echo "Wallpaper and colors updated!"
