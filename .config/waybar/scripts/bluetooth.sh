#!/usr/bin/env bash
# Bluetooth Wofi Control Script
# Author: Nick Clyde (clydedroid) — modified for Wofi

WOFI_THEME="${WOFI_THEME:-$HOME/.config/wofi/style.css}"

readonly divider="---------"
readonly goback="Back"

wofi_command=(wofi --dmenu --style "$WOFI_THEME" --height 300 --width 400)

get_controller_info() { bluetoothctl show; }
power_on() { get_controller_info | grep -q "Powered: yes"; }
scan_on() { get_controller_info | grep -q "Discovering: yes"; }
pairable_on() { get_controller_info | grep -q "Pairable: yes"; }
discoverable_on() { get_controller_info | grep -q "Discoverable: yes"; }

get_device_info() { bluetoothctl info "$1" 2>/dev/null; }
device_connected() { get_device_info "$1" | grep -q "Connected: yes"; }
device_paired() { get_device_info "$1" | grep -q "Paired: yes"; }
device_trusted() { get_device_info "$1" | grep -q "Trusted: yes"; }

send_notif() {
  notify-send "Bluetooth" "$1"
}

toggle_power() {
  if power_on; then
    bluetoothctl power off
    send_notif "Power turned off"
  else
    rfkill list bluetooth | grep -q 'blocked: yes' && rfkill unblock bluetooth && sleep 1
    bluetoothctl power on
    send_notif "Power turned on"
  fi
  show_menu
}

toggle_scan() {
  send_notif "Scanning for 10 seconds..."
  bluetoothctl scan on >/dev/null
  sleep 10
  bluetoothctl scan off
  send_notif "Scan finished."
  show_menu
}

toggle_pairable() {
  if pairable_on; then
    bluetoothctl pairable off
    send_notif "Pairable: off"
  else
    bluetoothctl pairable on
    send_notif "Pairable: on"
  fi
  show_menu
}

toggle_discoverable() {
  if discoverable_on; then
    bluetoothctl discoverable off
    send_notif "Discoverable: off"
  else
    bluetoothctl discoverable on
    send_notif "Discoverable: on"
  fi
  show_menu
}

toggle_connection() {
  if device_connected "$1"; then
    bluetoothctl disconnect "$1"
    send_notif "Device disconnected"
  else
    bluetoothctl connect "$1"
    send_notif "Device connected"
  fi
  device_menu "$device"
}

toggle_paired() {
  if device_paired "$1"; then
    bluetoothctl remove "$1"
    send_notif "Device unpaired"
  else
    bluetoothctl pair "$1"
    send_notif "Device paired"
  fi
  device_menu "$device"
}

toggle_trust() {
  if device_trusted "$1"; then
    bluetoothctl untrust "$1"
    send_notif "Device untrusted"
  else
    bluetoothctl trust "$1"
    send_notif "Device trusted"
  fi
  device_menu "$device"
}

print_status() {
  if power_on; then
    printf ''
    local paired_devices_cmd="devices Paired"
    [[ $(bluetoothctl version | awk '{print $2}') < 5.65 ]] && paired_devices_cmd="paired-devices"
    mapfile -t paired_devices < <(bluetoothctl $paired_devices_cmd | awk '/Device/ {print $2}')
    local counter=0
    for device_mac in "${paired_devices[@]}"; do
      if device_connected "$device_mac"; then
        local alias
        alias=$(get_device_info "$device_mac" | awk '/Alias/ {$1=""; print $0}' | xargs)
        printf "%s%s" "${counter:+, }" "$alias"
        ((counter++))
      fi
    done
    printf "\n"
  else
    echo ""
  fi
}

device_menu() {
  local device_line=$1
  local device_name=$(echo "$device_line" | awk '{$1=$2=""; print $0}' | xargs)
  local mac=$(echo "$device_line" | awk '{print $2}')

  local connected_status=$(device_connected "$mac" && echo "Connected: yes" || echo "Connected: no")
  local paired_status=$(device_paired "$mac" && echo "Paired: yes" || echo "Paired: no")
  local trusted_status=$(device_trusted "$mac" && echo "Trusted: yes" || echo "Trusted: no")

  local options="$connected_status\n$paired_status\n$trusted_status\n$divider\n$goback\nExit"
  local chosen
  chosen="$(echo -e "$options" | "${wofi_command[@]}" --prompt "$device_name")"

  case "$chosen" in
  "$connected_status") toggle_connection "$mac" ;;
  "$paired_status") toggle_paired "$mac" ;;
  "$trusted_status") toggle_trust "$mac" ;;
  "$goback") show_menu ;;
  esac
}

show_menu() {
  local menu_options power_status scan_status pairable_status discoverable_status

  if power_on; then
    power_status="Power: on"
    scan_status=$(scan_on && echo "Scan: on" || echo "Scan: off")
    pairable_status=$(pairable_on && echo "Pairable: on" || echo "Pairable: off")
    discoverable_status=$(discoverable_on && echo "Discoverable: on" || echo "Discoverable: off")

    # Refresh list of devices
    mapfile -t device_lines < <(bluetoothctl devices | grep ^Device)
    devices=""
    for line in "${device_lines[@]}"; do
      name=$(echo "$line" | cut -d ' ' -f 3-)
      devices+="$name"$'\n'
    done

    menu_options="$devices\n$divider\n$power_status\n$scan_status\n$pairable_status\n$discoverable_status\nExit"
  else
    power_status="Power: off"
    menu_options="$power_status\nExit"
  fi

  local chosen
  chosen="$(echo -e "$menu_options" | "${wofi_command[@]}" --prompt "Bluetooth")"

  case "$chosen" in
  "$power_status") toggle_power ;;
  "$scan_status") toggle_scan ;;
  "$pairable_status") toggle_pairable ;;
  "$discoverable_status") toggle_discoverable ;;
  *)
    local selected_device_line
    selected_device_line=$(bluetoothctl devices | grep "$chosen")
    [[ -n "$selected_device_line" ]] && device_menu "$selected_device_line"
    ;;
  esac
}

# --- Entry Point ---
case "$1" in
--status) print_status ;;
*) show_menu ;;
esac
