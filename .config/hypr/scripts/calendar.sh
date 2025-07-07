#!/bin/bash

# -- configuration --
WIDTH=300
HEIGHT=250
WAYBAR_HEIGHT=30
WAYBAR_POSITION="top"

# --- Script Behavior Settings ---
# Set to "true" for detailed output during execution, "false" for silent operation.
VERBOSE=true

# --- Functions ---
log() {
  if "$VERBOSE"; then
    echo "[$(basename "$0")] $1"
  fi
}

error_exit() {
  echo "Error: $1" >&2
  exit 1
}

# --- Dependency Check ---
command -v hyprctl >/dev/null || error_exit "hyprctl not found. Is Hyprland installed and in your PATH?"
command -v jq >/dev/null || error_exit "jq not found. Please install it (e.g., sudo pacman -S jq)."
command -v yad >/dev/null || error_exit "yad not found. Please install it (e.g., sudo pacman -S yad)."
command -v pgrep >/dev/null || error_exit "pgrep not found."

# --- Get Active Monitor Info ---
log "Getting active monitor details..."
# Get active monitor details (name, width, height, x_offset, y_offset)
# using jq to parse the JSON output from hyprctl monitors.
read -r MONITOR_NAME SCREEN_WIDTH SCREEN_HEIGHT MONITOR_X MONITOR_Y < <(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | "\(.name) \(.width) \(.height) \(.x) \(.y)"')

if [ -z "$SCREEN_WIDTH" ]; then
  error_exit "Could not determine active monitor details. Is Hyprland running or focused?"
fi
log "Active monitor: $MONITOR_NAME (${SCREEN_WIDTH}x${SCREEN_HEIGHT} at ${MONITOR_X},${MONITOR_Y})"

# --- Calculate Centered Position on Active Monitor ---
# Calculate horizontal center position relative to the monitor's X offset.
X_POS=$((MONITOR_X + (SCREEN_WIDTH / 2) - (WIDTH / 2)))

# Calculate vertical position based on Waybar's position.
if [ "$WAYBAR_POSITION" == "top" ]; then
  Y_POS=$((MONITOR_Y + WAYBAR_HEIGHT))
  log "Waybar is at the top. Positioning calendar below Waybar."
elif [ "$WAYBAR_POSITION" == "bottom" ]; then
  # Position the calendar just above Waybar at the bottom of the screen.
  Y_POS=$((MONITOR_Y + SCREEN_HEIGHT - HEIGHT - WAYBAR_HEIGHT))
  log "Waybar is at the bottom. Positioning calendar above Waybar."
else
  # Default to top if WAYBAR_POSITION is misconfigured.
  Y_POS=$((MONITOR_Y + WAYBAR_HEIGHT))
  log "Invalid WAYBAR_POSITION ('$WAYBAR_POSITION'). Defaulting to top."
fi
log "Calculated position: X=$X_POS, Y=$Y_POS"

# --- Toggle Logic ---
# Check if a yad calendar process is already running.
CALENDAR_PID=$(pgrep -f "yad --calendar --close-on-unfocus --no-buttons")

if [ -n "$CALENDAR_PID" ]; then
  # If already running, kill it to toggle off.
  log "Existing yad calendar found (PID: $CALENDAR_PID). Closing it..."
  kill "$CALENDAR_PID"
  # Wait briefly for the process to terminate before exiting the script.
  sleep 0.1
else
  # Launch yad calendar in the background.
  log "No existing yad calendar found. Launching new instance..."
  yad --calendar --close-on-unfocus --no-buttons \
    --width="$WIDTH" --height="$HEIGHT" &

  # Capture the PID of the newly launched yad instance.
  NEW_CALENDAR_PID=$!
  log "New yad calendar launched with PID: $NEW_CALENDAR_PID"

  # --- Wait for Window ID and Move ---
  WINDOW_ID=""
  MAX_RETRIES=20 # Increased retries for slower systems/launches.
  RETRIES=0
  log "Waiting for yad window to appear (max $MAX_RETRIES retries)..."
  while [ -z "$WINDOW_ID" ] && [ "$RETRIES" -lt "$MAX_RETRIES" ]; do
    sleep 0.05 # Reduced sleep time to make the loop faster.
    # Find the window by its class 'Yad' and ensure it matches our PID.
    WINDOW_ID=$(hyprctl clients -j | jq -r --argjson pid "$NEW_CALENDAR_PID" '.[] | select(.class == "Yad" and .pid == $pid) | .address')
    RETRIES=$((RETRIES + 1))
  done

  if [ -n "$WINDOW_ID" ]; then
    # Move the window using Hyprland's dispatch.
    log "Found window ID: $WINDOW_ID. Moving to $X_POS,$Y_POS..."
    hyprctl dispatch movewindowpixel exact "$WINDOW_ID" "$X_POS" "$Y_POS"
    log "Calendar positioned successfully."
  else
    log "Warning: Could not find yad calendar window ID after launch (retries: $RETRIES). Manual positioning might be needed."
  fi
fi
