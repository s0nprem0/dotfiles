#!/usr/bin/env bash

# WOFI_THEME is typically not directly used like ROFI_THEME with -theme flag
# Wofi relies on CSS themes. You can specify a CSS file using -s.
# If you have a specific wofi stylesheet for wifi, you'd reference it here.
# For simplicity, we'll remove it for now and assume default wofi styling or system-wide wofi CSS.
# WOFI_CSS_FILE="$HOME/.config/wofi/style-wifi.css" # Example if you have a specific CSS

# Returns a Wi-Fi signal icon for a given strength (0–100)
get_signal_icon() {
  local strength=$1
  if ((strength >= 80)); then
    echo "󰤨"
  elif ((strength >= 60)); then
    echo "󰤥"
  elif ((strength >= 40)); then
    echo "󰤢"
  elif ((strength >= 20)); then
    echo "󰤟"
  else
    echo "󰤯"
  fi
}

# Show Wi-Fi status with dynamic icon
display_wifi_status() {
  local ssid strength wifi_state icon

  # Use full paths for nmcli to avoid PATH issues when run by Waybar
  ssid=$(/usr/bin/nmcli -t -f active,ssid dev wifi | awk -F: '$1 == "yes" {print $2}')
  strength=$(/usr/bin/nmcli -t -f active,signal dev wifi | awk -F: '$1 == "yes" {print $2}')
  wifi_state=$(/usr/bin/nmcli -t -f WIFI g)

  if [[ -n "$ssid" ]]; then
    icon=$(get_signal_icon "$strength")
    echo "$icon  $ssid ($strength%)"
  else
    if [[ "$wifi_state" == "enabled" ]]; then
      echo "󰤯  Disconnected"
    else
      echo "󰖩  Wi-Fi Off"
    fi
  fi
}

# Use wofi to connect to a Wi-Fi network
connect_wifi() {
  /usr/bin/notify-send "Wi-Fi" "Fetching available networks..." # Use full path for notify-send

  local wifi_list saved_connections wifi_state toggle hidden_option chosen_network chosen_id ssid password

  saved_connections=$(/usr/bin/nmcli -t -f NAME connection show)

  wifi_list=$(/usr/bin/nmcli -t -f SSID,SECURITY,SIGNAL device wifi list | awk -F: '
  {
    if ($1 == "") next;
    icon = ($2 ~ /WPA/) ? "" : ""; # WPA icon, Open icon
    printf "%s %s (%s%%)\n", icon, $1, $3;
  }')

  wifi_state=$(/usr/bin/nmcli -t -f WIFI g)
  toggle="󰖪  Disable Wi-Fi"
  [[ "$wifi_state" != "enabled" ]] && toggle="󰖩  Enable Wi-Fi"

  hidden_option="󰐗  Connect to Hidden Network"

  chosen_network=$(
    echo -e "$toggle\n$hidden_option\n$wifi_list" | uniq -u |
      /usr/bin/wofi --show dmenu -i --prompt "Wi-Fi SSID: " \
        -dmenu -lines 10 -columns 1 --width 400 --height 300 \
        -location 0 -x 0 -y 0 --allow-markup # Wofi options for dmenu, position, size. No direct -theme like rofi.
  )
  chosen_id="${chosen_network:3}" # Remove icon and extra space from start
  [[ -z "$chosen_network" ]] && exit

  case "$chosen_network" in
  "󰖩  Enable Wi-Fi")
    /usr/bin/nmcli radio wifi on && /usr/bin/notify-send "Wi-Fi" "Wi-Fi Enabled"
    ;;
  "󰖪  Disable Wi-Fi")
    /usr/bin/nmcli radio wifi off && /usr/bin/notify-send "Wi-Fi" "Wi-Fi Disabled"
    ;;
  "$hidden_option")
    ssid=$(/usr/bin/wofi --show dmenu --prompt "Enter Hidden SSID: " \
      -dmenu -lines 1 -columns 1 --width 400 --height 50 -location 0 -x 0 -y 0 --allow-markup)
    [[ -z "$ssid" ]] && exit
    password=$(/usr/bin/wofi --show dmenu --prompt "Enter Password (leave empty if open): " \
      -dmenu -lines 1 -columns 1 --width 400 --height 50 -location 0 -x 0 -y 0 --allow-markup)
    if [[ -n "$password" ]]; then
      if /usr/bin/nmcli device wifi connect "$ssid" password "$password" hidden yes; then
        /usr/bin/notify-send "Wi-Fi" "Connected to \"$ssid\""
      else
        /usr/bin/notify-send "Wi-Fi" "Connection Failed: Could not connect to \"$ssid\""
      fi
    else
      if /usr/bin/nmcli device wifi connect "$ssid" hidden yes; then
        /usr/bin/notify-send "Wi-Fi" "Connected to \"$ssid\""
      else
        /usr/bin/notify-send "Wi-Fi" "Connection Failed: Could not connect to \"$ssid\""
      fi
    fi
    ;;
  *)
    # Extract the actual SSID from the chosen_network string (e.g., " MyNetwork (80%)")
    # This regex ensures we only get the SSID part, ignoring icon and strength.
    if [[ "$chosen_network" =~ ^(.)\ +([^\(]+)\ \(([0-9]+%)?\)$ ]]; then
      chosen_id="${BASH_REMATCH[2]}"
      # Trim leading/trailing spaces if any
      chosen_id=$(echo "$chosen_id" | xargs)
    else
      # Fallback if regex doesn't match, assumes chosen_network is just the ID after icon removal
      chosen_id="${chosen_network:3}"
      chosen_id=$(echo "$chosen_id" | xargs)
    fi

    password=""
    if [[ "$chosen_network" =~ "" ]]; then # Check if network has lock icon (WPA/security)
      password=$(/usr/bin/wofi --show dmenu --prompt "Enter Password: " \
        -dmenu -lines 1 -columns 1 --width 400 --height 50 -location 0 -x 0 -y 0 --allow-markup)
    fi

    # Connect using existing connection ID or create new one
    if echo "$saved_connections" | grep -Fxq "$chosen_id"; then
      if /usr/bin/nmcli connection up id "$chosen_id"; then
        /usr/bin/notify-send "Wi-Fi" "Connected to \"$chosen_id\""
      else
        /usr/bin/notify-send "Wi-Fi" "Connection Failed: Could not connect to \"$chosen_id\""
      fi
    else
      # Attempt to connect, password will be used if provided, otherwise it's an open network
      if /usr/bin/nmcli device wifi connect "$chosen_id" password "$password"; then
        /usr/bin/notify-send "Wi-Fi" "Connected to \"$chosen_id\""
      else
        /usr/bin/notify-send "Wi-Fi" "Connection Failed: Could not connect to \"$chosen_id\""
      fi
    fi
    ;;
  esac
}

# Toggle Wi-Fi On/Off
toggle_wifi() {
  local state
  state=$(/usr/bin/nmcli -t -f WIFI g)
  if [[ "$state" == "enabled" ]]; then
    /usr/bin/nmcli radio wifi off && /usr/bin/notify-send "Wi-Fi" "Wi-Fi Disabled"
  else
    /usr/bin/nmcli radio wifi on && /usr/bin/notify-send "Wi-Fi" "Wi-Fi Enabled"
  fi
}

# Main script execution
case "$1" in
--connect)
  connect_wifi
  ;;
--toggle)
  toggle_wifi
  ;;
*)
  # Auto-connect logic if disconnected
  current_ssid=$(/usr/bin/nmcli -t -f active,ssid dev wifi | awk -F: '$1 == "yes" {print $2}')
  if [[ -z "$current_ssid" ]]; then
    available_networks=$(/usr/bin/nmcli -t -f SSID,SIGNAL dev wifi | sort -t: -k2 -nr)
    saved_connections=$(/usr/bin/nmcli -t -f NAME connection show)

    while IFS=: read -r ssid signal; do
      [[ -z "$ssid" ]] && continue
      if echo "$saved_connections" | grep -Fxq "$ssid"; then
        if ((signal >= 30)); then # Added condition: only connect if signal is >= 30%
          if /usr/bin/nmcli connection up id "$ssid"; then
            /usr/bin/notify-send "Wi-Fi" "Auto Connected to \"$ssid\" (Signal: $signal%)"
          fi
          break
        fi
      fi
    done <<<"$available_networks"
  fi

  display_wifi_status
  ;;
esac
