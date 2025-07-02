#!/bin/bash

# Define config and style paths
NOTIFY_ICON="$HOME/.config/dotfiles/fastfetch/moon.png" # Assuming this path is correct

echo "Attempting to gracefully restart Waybar, SwayNC, and reload Hyprland..."

# Kill existing instances (more robust with pkill and checks)
pkill -f waybar && echo "Waybar killed." || echo "Waybar not running."
pkill -f swaync && echo "SwayNC killed." || echo "SwayNC not running."

# Small delay to ensure processes are terminated
sleep 0.5

# Start Waybar
# Note: This assumes Waybar auto-detects its config (e.g., ~/.config/waybar/config.jsonc)
# and style (e.g., ~/.config/waybar/style.css).
# If your files are strictly in ~/.config/dotfiles/waybar/ without symlinks,
# Waybar will NOT find them with this simplified command.
if [ -f "$HOME/.config/waybar/config.jsonc" ]; then # Check for default config path
  echo "Starting Waybar..."
  waybar &      # Simplified command
  WAYBAR_PID=$! # Capture PID
  echo "Waybar started with PID: $WAYBAR_PID"
else
  echo "Error: Default Waybar config file (~/.config/waybar/config.jsonc) not found. Skipping Waybar start."
  echo "If your config is in a non-default location, you must specify it with '-c' and '-s'."
fi

# Start SwayNC
# Note: This assumes SwayNC auto-detects its config (e.g., ~/.config/swaync/config.json)
# and style (e.g., ~/.config/swaync/style.css).
# If your files are strictly in ~/.config/dotfiles/swaync/ without symlinks,
# SwayNC will NOT find them with this simplified command.
if [ -f "$HOME/.config/swaync/config.json" ]; then # Check for default config path
  echo "Starting SwayNC..."
  swaync &      # Simplified command
  SWAYNC_PID=$! # Capture PID
  echo "SwayNC started with PID: $SWAYNC_PID"
else
  echo "Error: Default SwayNC config file (~/.config/swaync/config.json) not found. Skipping SwayNC start."
  echo "If your config is in a non-default location, you must specify it with '-c' and '-s'."
fi

# Reload Hyprland configuration
hyprctl reload && echo "Hyprland configuration reloaded." || echo "Failed to reload Hyprland configuration."

# Send a notification to confirm reload
notify-send --app-name="System Reload" -i "$NOTIFY_ICON" "Reload Complete" "Hyprland, Waybar, and SwayNC have been reloaded."
