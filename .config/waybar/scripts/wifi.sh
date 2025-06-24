#!/usr/bin/env bash

# --- Configuration ---
NMCLI="/usr/bin/nmcli"
WOFI="/usr/bin/wofi"
NOTIFY_SEND="/usr/bin/notify-send"
CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/network-manager.conf"

# Load interface names from config file if exists
if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
else
  # Default fallback interfaces
  WIFI_IFACE="wlan0"
  ETH_IFACE="eth0"
fi

# --- Dependency Checks ---
check_dependencies() {
  local missing=()
  [[ -x "$NMCLI" ]] || missing+=("nmcli")
  [[ -x "$WOFI" ]] || missing+=("wofi")
  [[ -x "$NOTIFY_SEND" ]] || missing+=("notify-send")

  if ((${#missing[@]} > 0)); then
    echo "Error: Missing required dependencies: ${missing[*]}"
    exit 1
  fi
}

# --- Helper Functions ---
show_notification() {
  local title="$1"
  local message="$2"
  "$NOTIFY_SEND" "$title" "$message"
}

nmcli_try() {
  if ! "$NMCLI" "$@" 2>/dev/null; then
    return 1
  fi
  return 0
}

nmcli_with_notify() {
  local success_msg="$1"
  local error_msg="$2"
  shift 2

  if nmcli_try "$@"; then
    [[ -n "$success_msg" ]] && show_notification "Success" "$success_msg"
    return 0
  else
    show_notification "Error" "${error_msg:-"Failed to execute nmcli command"}"
    return 1
  fi
}

get_active_connection() {
  local iface="$1"
  nmcli -t -f NAME,DEVICE connection show --active | awk -F: -v iface="$iface" '$2 == iface {print $1}'
}

# --- Wi-Fi Menu ---
wifi_menu() {
  show_notification "Wi-Fi" "Scanning for networks..."

  # Get current Wi-Fi state
  local wifi_state
  wifi_state=$(nmcli -t -f WIFI g)

  # Ensure Wi-Fi is enabled
  if [[ "$wifi_state" != "enabled" ]]; then
    nmcli_with_notify "Wi-Fi enabled" "Failed to enable Wi-Fi" radio wifi on
    sleep 0.5
    wifi_state=$(nmcli -t -f WIFI g)
    [[ "$wifi_state" != "enabled" ]] && return 1
  fi

  # Get current connection info
  local current_ssid current_signal
  read -r current_ssid current_signal <<< \
    $(nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi | awk -F: '$1 == "yes" {print $2, $3; exit}')

  # Build menu options
  local menu_options=()
  [[ -n "$current_ssid" ]] && menu_options+=("󰐥 Disconnect from $current_ssid ($current_signal%)")
  menu_options+=(
    "$([[ "$wifi_state" == "enabled" ]] && echo "󰖪 Disable Wi-Fi" || echo "󰖩 Enable Wi-Fi")"
    "󰐗 Connect to Hidden Network"
  )

  # Add available networks
  while IFS=: read -r ssid security signal; do
    [[ -z "$ssid" ]] && continue
    local icon=$([[ "$security" =~ (WPA|WEP) ]] && echo "" || echo "")
    menu_options+=("$icon $ssid ($signal%)")
  done < <(nmcli -t -f SSID,SECURITY,SIGNAL device wifi list | sort -t: -k3nr)

  # Show menu
  local chosen
  chosen=$(printf '%s\n' "${menu_options[@]}" |
    "$WOFI" --show dmenu -i --prompt "Wi-Fi:" \
      -dmenu -lines 10 -width 400 -height 300)

  [[ -z "$chosen" ]] && return 0

  case "$chosen" in
  "󰖩 Enable Wi-Fi")
    nmcli_with_notify "Wi-Fi enabled" "Failed to enable Wi-Fi" radio wifi on
    ;;
  "󰖪 Disable Wi-Fi")
    nmcli_with_notify "Wi-Fi disabled" "Failed to disable Wi-Fi" radio wifi off
    ;;
  "󰐥 Disconnect from "*)
    local ssid="${chosen#󰐥 Disconnect from }"
    ssid="${ssid% (*}"
    nmcli_with_notify "Disconnected from $ssid" "Failed to disconnect" connection down "$ssid"
    ;;
  "󰐗 Connect to Hidden Network")
    local ssid password
    ssid=$("$WOFI" --show dmenu --prompt "Hidden SSID:")
    [[ -z "$ssid" ]] && return 0

    password=$("$WOFI" --show dmenu --prompt "Password (leave empty if open):")
    if [[ -n "$password" ]]; then
      nmcli_with_notify "Connected to hidden network" "Connection failed" \
        device wifi connect "$ssid" password "$password" hidden yes
    else
      nmcli_with_notify "Connected to hidden network" "Connection failed" \
        device wifi connect "$ssid" hidden yes
    fi
    ;;
  *)
    local ssid="${chosen#* }"
    ssid="${ssid% (*}"
    local security="${chosen%% *}"

    if [[ "$security" == "" ]]; then
      password=$("$WOFI" --show dmenu --prompt "Password for $ssid:")
      [[ -z "$password" ]] && return 0
      nmcli_with_notify "Connected to $ssid" "Connection failed" \
        device wifi connect "$ssid" password "$password"
    else
      nmcli_with_notify "Connected to $ssid" "Connection failed" \
        device wifi connect "$ssid"
    fi
    ;;
  esac
}

# --- Ethernet Menu ---
ethernet_menu() {
  local eth_state
  eth_state=$(nmcli -t -f DEVICE,STATE dev | awk -F: -v iface="$ETH_IFACE" '$1 == iface {print $2}')

  # Build menu options
  local menu_options=()
  if [[ "$eth_state" == "connected" || "$eth_state" == "connecting" ]]; then
    menu_options+=("󰐥 Disconnect Ethernet")
  fi
  menu_options+=(
    "󰈀 Enable Ethernet (DHCP)"
    "󰈀 Disable Ethernet"
  )

  # Show menu
  local chosen
  chosen=$(printf '%s\n' "${menu_options[@]}" |
    "$WOFI" --show dmenu -i --prompt "Ethernet:" \
      -dmenu -lines 5 -width 300 -height 150)

  [[ -z "$chosen" ]] && return 0

  case "$chosen" in
  "󰈀 Enable Ethernet (DHCP)")
    nmcli_with_notify "Ethernet enabled" "Failed to enable Ethernet" device connect "$ETH_IFACE"
    ;;
  "󰈀 Disable Ethernet")
    nmcli_with_notify "Ethernet disabled" "Failed to disable Ethernet" device disconnect "$ETH_IFACE"
    ;;
  "󰐥 Disconnect Ethernet")
    local conn
    conn=$(get_active_connection "$ETH_IFACE")
    if [[ -n "$conn" ]]; then
      nmcli_with_notify "Disconnected from $conn" "Failed to disconnect" connection down "$conn"
    else
      show_notification "Info" "No active Ethernet connection"
    fi
    ;;
  esac
}

# --- VPN Menu ---
vpn_menu() {
  show_notification "VPN" "Loading VPN connections..."

  # Get VPN list and active connection
  local vpns=()
  while IFS=: read -r name type; do
    [[ "$type" == "vpn" ]] && vpns+=("$name")
  done < <(nmcli -t -f NAME,TYPE connection show)

  local active_vpn
  active_vpn=$(nmcli -t -f NAME,TYPE connection show --active | awk -F: '$2 == "vpn" {print $1}')

  # Build menu options
  local menu_options=()
  [[ -n "$active_vpn" ]] && menu_options+=("󰐥 Disconnect VPN ($active_vpn)")

  for vpn in "${vpns[@]}"; do
    [[ "$vpn" != "$active_vpn" ]] && menu_options+=("🔒 Connect $vpn")
  done

  if ((${#menu_options[@]} == 0)); then
    show_notification "VPN" "No VPN configurations found"
    return 0
  fi

  # Show menu
  local chosen
  chosen=$(printf '%s\n' "${menu_options[@]}" |
    "$WOFI" --show dmenu -i --prompt "VPN:" \
      -dmenu -lines 10 -width 400 -height 300)

  [[ -z "$chosen" ]] && return 0

  if [[ "$chosen" == "󰐥 Disconnect VPN ("* ]]; then
    local vpn="${chosen#󰐥 Disconnect VPN (}"
    vpn="${vpn%)}"
    nmcli_with_notify "Disconnected from $vpn" "Failed to disconnect" connection down "$vpn"
  elif [[ "$chosen" == "🔒 Connect "* ]]; then
    local vpn="${chosen#🔒 Connect }"
    nmcli_with_notify "Connecting to $vpn" "Connection failed" connection up "$vpn"
  fi
}

# --- Main Menu ---
main_menu() {
  local chosen
  chosen=$(printf '%s\n' "Wi-Fi Connections" "Ethernet Connections" "VPN Connections" |
    "$WOFI" --show dmenu -i --prompt "Network Menu:" \
      -dmenu -lines 3 -width 300 -height 150)

  case "$chosen" in
  "Wi-Fi Connections") wifi_menu ;;
  "Ethernet Connections") ethernet_menu ;;
  "VPN Connections") vpn_menu ;;
  esac
}

# --- Main Execution ---
check_dependencies

case "$1" in
--menu) main_menu ;;
*)
  echo "Usage: $0 --menu"
  exit 1
  ;;
esac
