#!/usr/bin/env bash
set -euo pipefail

PRESET_FILE="${1:-}"
if [[ -z "$PRESET_FILE" || ! -f "$PRESET_FILE" ]]; then
  echo '{"error":"Preset file not found"}' >&2
  exit 1
fi

CACHE_DIR="$HOME/.cache/quickshell"
mkdir -p "$CACHE_DIR"

colors_json="$CACHE_DIR/colors.json"
colors_qml="$CACHE_DIR/Colors.qml"

# Extract shell colors from preset JSON
BG=$(jq -r '.shell.bg' "$PRESET_FILE")
FG=$(jq -r '.shell.fg' "$PRESET_FILE")
SURFACE=$(jq -r '.shell.surface' "$PRESET_FILE")
SURFACE_LIGHTER=$(jq -r '.shell.surfaceLighter' "$PRESET_FILE")
PRIMARY=$(jq -r '.shell.primary' "$PRESET_FILE")
MUTED=$(jq -r '.shell.muted' "$PRESET_FILE")
ERROR=$(jq -r '.shell.error' "$PRESET_FILE")
WARNING=$(jq -r '.shell.warning' "$PRESET_FILE")
GREEN=$(jq -r '.shell.green' "$PRESET_FILE")
BLUE=$(jq -r '.shell.blue' "$PRESET_FILE")

# Write colors.json
cat > "$colors_json" << JSONEOF
{
  "bg": "$BG",
  "fg": "$FG",
  "surface": "$SURFACE",
  "surfaceLighter": "$SURFACE_LIGHTER",
  "primary": "$PRIMARY",
  "muted": "$MUTED",
  "error": "$ERROR",
  "warning": "$WARNING",
  "green": "$GREEN",
  "blue": "$BLUE"
}
JSONEOF

# Write Colors.qml
cat > "$colors_qml" << QMLEOF
pragma Singleton
QtObject {
    property color bg: "$BG"
    property color fg: "$FG"
    property color surface: "$SURFACE"
    property color surfaceLighter: "$SURFACE_LIGHTER"
    property color primary: "$PRIMARY"
    property color muted: "$MUTED"
    property color error: "$ERROR"
    property color warning: "$WARNING"
    property color green: "$GREEN"
    property color blue: "$BLUE"
    property color tertiary: "$SURFACE_LIGHTER"
}
QMLEOF

# Update hyprland colors if preset has them
HP_COLORS="$HOME/.config/hypr/colors.lua"
HP_ACCENT=$(jq -r '.hyprland.accent // ""' "$PRESET_FILE" 2>/dev/null)
HP_SURFACE=$(jq -r '.hyprland.surface // ""' "$PRESET_FILE" 2>/dev/null)
HP_ON_SURFACE=$(jq -r '.hyprland.on_surface // ""' "$PRESET_FILE" 2>/dev/null)
HP_ERROR=$(jq -r '.hyprland.error_hex // ""' "$PRESET_FILE" 2>/dev/null)

if [[ -n "$HP_ACCENT" && -f "$HP_COLORS" ]]; then
  cat > "$HP_COLORS" << LUAMOF
return {
  accent = "$HP_ACCENT",
  surface = "$HP_SURFACE",
  on_surface = "$HP_ON_SURFACE",
  error_hex = "$HP_ERROR",
}
LUAMOF
fi

# Update hyprlock colors
HP_LOCK="$HOME/.config/hypr/colors-hyprlock.conf"
if [[ -n "$HP_ACCENT" && -f "$HP_LOCK" ]]; then
  cat > "$HP_LOCK" << LOCKEOF
\$accent = rgb($HP_ACCENT)
\$surface = rgb($HP_SURFACE)
\$on_surface = rgb($HP_ON_SURFACE)
LOCKEOF
fi

# Run theme switcher if wallpaper exists
WALLPAPER_FILE="$CACHE_DIR/current_wallpaper"
if [[ -f "$WALLPAPER_FILE" ]]; then
  WALLPAPER=$(cat "$WALLPAPER_FILE")
  if [[ -f "$WALLPAPER" ]]; then
    THEME_SWITCHER="$HOME/dotfiles/scripts/theme_switcher"
    if [[ -f "$THEME_SWITCHER" ]]; then
      bash "$THEME_SWITCHER" --apps kitty,gtk3,gtk4,vesktop,thunar,spicetify,zathura,bat,btop,eza,fastfetch "$WALLPAPER" 2>/dev/null || true
    fi
  fi
fi

echo '{"ok":true}'
