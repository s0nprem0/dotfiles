#!/usr/bin/env bash

ROFI_THEME="$HOME/.config/rofi/wifi.rasi"

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

  ssid=$(nmcli -t -f active,ssid dev wifi | awk -F: '$1 == "yes" {print $2}')
  strength=$(nmcli -t -f active,signal dev wifi | awk -F: '$1 == "yes" {print $2}')
  wifi_state=$(nmcli -t -f WIFI g)

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

# Use rofi to connect to a Wi-Fi network
connect_wifi() {
  notify-send "Wi-Fi" "Fetching available networks..."

  local wifi_list saved_connections wifi_state toggle hidden_option chosen_network chosen_id ssid password

  saved_connections=$(nmcli -t -f NAME connection show)

  wifi_list=$(nmcli -t -f SSID,SECURITY,SIGNAL device wifi list | awk -F: '
  {
    if ($1 == "") next;
    icon = ($2 ~ /WPA/) ? "" : "";
    printf "%s %s (%s%%)\n", icon, $1, $3;
  }')

  wifi_state=$(nmcli -t -f WIFI g)
  toggle="󰖪  Disable Wi-Fi"
  [[ "$wifi_state" != "enabled" ]] && toggle="󰖩  Enable Wi-Fi"

  hidden_option="󰐗  Connect to Hidden Network"

  chosen_network=$(echo -e "$toggle\n$hidden_option\n$wifi_list" | uniq -u |
    rofi -dmenu -i -selected-row 2 -p "Wi-Fi SSID: " -theme "$ROFI_THEME")
  chosen_id="${chosen_network:3}"
  [[ -z "$chosen_network" ]] && exit

  case "$chosen_network" in
  "󰖩  Enable Wi-Fi")
    nmcli radio wifi on && notify-send "Wi-Fi Enabled"
    ;;
  "󰖪  Disable Wi-Fi")
    nmcli radio wifi off && notify-send "Wi-Fi Disabled"
    ;;
  "$hidden_option")
    ssid=$(rofi -dmenu -p "Enter Hidden SSID: " -theme "$ROFI_THEME")
    [[ -z "$ssid" ]] && exit
    password=$(rofi -dmenu -p "Enter Password (leave empty if open): " -theme "$ROFI_THEME")
    if [[ -n "$password" ]]; then
      if nmcli device wifi connect "$ssid" password "$password" hidden yes; then
        notify-send "Connected" "Connected to \"$ssid\""
      else
        notify-send "Connection Failed" "Could not connect to \"$ssid\""
      fi
    else
      if nmcli device wifi connect "$ssid" hidden yes; then
        notify-send "Connected" "Connected to \"$ssid\""
      else
        notify-send "Connection Failed" "Could not connect to \"$ssid\""
      fi
    fi
    ;;
  *)
    if [[ "$chosen_network" =~ "" ]]; then
      password=$(rofi -dmenu -p "Enter Password: " -theme "$ROFI_THEME")
    fi

    if echo "$saved_connections" | grep -Fxq "$chosen_id"; then
      if nmcli connection up id "$chosen_id"; then
        notify-send "Connected" "Connected to \"$chosen_id\""
      else
        notify-send "Connection Failed" "Could not connect to \"$chosen_id\""
      fi
    else
      if nmcli device wifi connect "$chosen_id" password "$password"; then
        notify-send "Connected" "Connected to \"$chosen_id\""
      else
        notify-send "Connection Failed" "Could not connect to \"$chosen_id\""
      fi
    fi
    ;;
  esac
}

# Toggle Wi-Fi On/Off
toggle_wifi() {
  local state
  state=$(nmcli -t -f WIFI g)
  if [[ "$state" == "enabled" ]]; then
    nmcli radio wifi off && notify-send "Wi-Fi Disabled"
  else
    nmcli radio wifi on && notify-send "Wi-Fi Enabled"
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
  current_ssid=$(nmcli -t -f active,ssid dev wifi | awk -F: '$1 == "yes" {print $2}')
  if [[ -z "$current_ssid" ]]; then
    available_networks=$(nmcli -t -f SSID,SIGNAL dev wifi | sort -t: -k2 -nr)
    saved_connections=$(nmcli -t -f NAME connection show)

    while IFS=: read -r ssid signal; do
      [[ -z "$ssid" ]] && continue
      if echo "$saved_connections" | grep -Fxq "$ssid"; then
        if nmcli connection up id "$ssid"; then
          notify-send "Auto Connected" "Connected to \"$ssid\""
        fi
        break
      fi
    done <<<"$available_networks"
  fi

  display_wifi_status
  ;;
esac
