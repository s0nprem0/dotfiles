#!/usr/bin/env bash

NMCLI="/usr/bin/nmcli"
WOFI="/usr/bin/wofi"
NOTIFY_SEND="/usr/bin/notify-send"

# Auto-detect interfaces from nmcli
detect_interfaces() {
  WIFI_IFACE=$("$NMCLI" -t -f TYPE,DEVICE device 2>/dev/null | awk -F: '$1 == "wifi" {print $2; exit}')
  ETH_IFACE=$("$NMCLI" -t -f TYPE,DEVICE device 2>/dev/null | awk -F: '$1 == "ethernet" {print $2; exit}')
  : "${WIFI_IFACE:=wlan0}"
  : "${ETH_IFACE:=eth0}"
}
detect_interfaces

# Config file override
CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/network-manager.conf"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

check_dependencies() {
  local missing=()
  [[ -x "$NMCLI" ]] || missing+=("nmcli")
  [[ -x "$WOFI" ]] || missing+=("wofi")
  [[ -x "$NOTIFY_SEND" ]] || missing+=("notify-send")
  if ((${#missing[@]} > 0)); then
    echo "Error: Missing dependencies: ${missing[*]}" >&2
    exit 1
  fi
}

show_notification() { "$NOTIFY_SEND" "$1" "$2"; }

nmcli_try() { "$NMCLI" "$@" 2>/dev/null; }

nmcli_with_notify() {
  local success_msg="$1" error_msg="$2"
  shift 2
  if nmcli_try "$@"; then
    [[ -n "$success_msg" ]] && show_notification "Success" "$success_msg"
  else
    show_notification "Error" "${error_msg:-Command failed}"
    return 1
  fi
}

get_active_connection() {
  nmcli -t -f NAME,DEVICE connection show --active | awk -F: -v iface="$1" '$2 == iface {print $1}'
}

wifi_menu() {
  show_notification "Wi-Fi" "Scanning..."

  local wifi_state
  wifi_state=$(nmcli -t -f WIFI g)

  if [[ "$wifi_state" != "enabled" ]]; then
    nmcli_with_notify "Wi-Fi enabled" "Failed to enable Wi-Fi" radio wifi on
    sleep 0.5
    wifi_state=$(nmcli -t -f WIFI g)
    [[ "$wifi_state" != "enabled" ]] && return 1
  fi

  local current_ssid current_signal
  read -r current_ssid current_signal <<< \
    $(nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi | awk -F: '$1 == "yes" {print $2, $3; exit}')

  local menu_options=()
  [[ -n "$current_ssid" ]] && menu_options+=("󰐥 Disconnect from $current_ssid ($current_signal%)")
  menu_options+=(
    "$([[ "$wifi_state" == "enabled" ]] && echo "󰖪 Disable Wi-Fi" || echo "󰖩 Enable Wi-Fi")"
    "󰐗 Connect to Hidden Network"
  )

  while IFS=: read -r ssid security signal; do
    [[ -z "$ssid" ]] && continue
    local icon=$([[ "$security" =~ (WPA|WEP) ]] && echo "" || echo "")
    menu_options+=("$icon $ssid ($signal%)")
  done < <(nmcli -t -f SSID,SECURITY,SIGNAL device wifi list | sort -t: -k3nr)

  local chosen
  chosen=$(printf '%s\n' "${menu_options[@]}" |
    "$WOFI" --show dmenu -i --prompt "Wi-Fi:" -dmenu -lines 10 -width 400 -height 300)

  [[ -z "$chosen" ]] && return 0

  case "$chosen" in
  "󰖩 Enable Wi-Fi") nmcli_with_notify "Wi-Fi enabled" "Failed to enable Wi-Fi" radio wifi on ;;
  "󰖪 Disable Wi-Fi") nmcli_with_notify "Wi-Fi disabled" "Failed to disable Wi-Fi" radio wifi off ;;
  "󰐥 Disconnect from "*)
    local ssid="${chosen#󰐥 Disconnect from }"
    ssid="${ssid% (*}"
    nmcli_with_notify "Disconnected" "Failed to disconnect" connection down "$ssid"
    ;;
  "󰐗 Connect to Hidden Network")
    local ssid password
    ssid=$("$WOFI" --show dmenu --prompt "Hidden SSID:")
    [[ -z "$ssid" ]] && return 0
    password=$("$WOFI" --show dmenu --prompt "Password (leave empty):")
    if [[ -n "$password" ]]; then
      nmcli_with_notify "Connected" "Connection failed" device wifi connect "$ssid" password "$password" hidden yes
    else
      nmcli_with_notify "Connected" "Connection failed" device wifi connect "$ssid" hidden yes
    fi
    ;;
  *)
    local ssid="${chosen#* }"
    ssid="${ssid% (*}"
    local security="${chosen%% *}"
    if [[ "$security" == "" ]]; then
      password=$("$WOFI" --show dmenu --prompt "Password for $ssid:")
      [[ -z "$password" ]] && return 0
      nmcli_with_notify "Connected" "Connection failed" device wifi connect "$ssid" password "$password"
    else
      nmcli_with_notify "Connected" "Connection failed" device wifi connect "$ssid"
    fi
    ;;
  esac
}

ethernet_menu() {
  local eth_state
  eth_state=$(nmcli -t -f DEVICE,STATE dev | awk -F: -v iface="$ETH_IFACE" '$1 == iface {print $2}')

  local menu_options=()
  if [[ "$eth_state" == "connected" || "$eth_state" == "connecting" ]]; then
    menu_options+=("󰐥 Disconnect Ethernet")
  fi
  menu_options+=("󰈀 Enable Ethernet (DHCP)" "󰈀 Disable Ethernet")

  local chosen
  chosen=$(printf '%s\n' "${menu_options[@]}" |
    "$WOFI" --show dmenu -i --prompt "Ethernet:" -dmenu -lines 5 -width 300 -height 150)
  [[ -z "$chosen" ]] && return 0

  case "$chosen" in
  "󰈀 Enable Ethernet (DHCP)") nmcli_with_notify "Ethernet enabled" "Failed" device connect "$ETH_IFACE" ;;
  "󰈀 Disable Ethernet") nmcli_with_notify "Ethernet disabled" "Failed" device disconnect "$ETH_IFACE" ;;
  "󰐥 Disconnect Ethernet")
    local conn
    conn=$(get_active_connection "$ETH_IFACE")
    if [[ -n "$conn" ]]; then
      nmcli_with_notify "Disconnected" "Failed" connection down "$conn"
    else
      show_notification "Info" "No active Ethernet connection"
    fi
    ;;
  esac
}

vpn_menu() {
  show_notification "VPN" "Loading connections..."

  local vpns=()
  while IFS=: read -r name type; do
    [[ "$type" == "vpn" ]] && vpns+=("$name")
  done < <(nmcli -t -f NAME,TYPE connection show)

  local active_vpn
  active_vpn=$(nmcli -t -f NAME,TYPE connection show --active | awk -F: '$2 == "vpn" {print $1}')

  local menu_options=()
  [[ -n "$active_vpn" ]] && menu_options+=("󰐥 Disconnect VPN ($active_vpn)")
  for vpn in "${vpns[@]}"; do
    [[ "$vpn" != "$active_vpn" ]] && menu_options+=(" Connect $vpn")
  done

  if ((${#menu_options[@]} == 0)); then
    show_notification "VPN" "No VPN configurations found"
    return 0
  fi

  local chosen
  chosen=$(printf '%s\n' "${menu_options[@]}" |
    "$WOFI" --show dmenu -i --prompt "VPN:" -dmenu -lines 10 -width 400 -height 300)
  [[ -z "$chosen" ]] && return 0

  if [[ "$chosen" == "󰐥 Disconnect VPN ("* ]]; then
    local vpn="${chosen#󰐥 Disconnect VPN (}"
    vpn="${vpn%)}"
    nmcli_with_notify "Disconnected" "Failed" connection down "$vpn"
  elif [[ "$chosen" == " Connect "* ]]; then
    local vpn="${chosen# Connect }"
    nmcli_with_notify "Connecting" "Failed" connection up "$vpn"
  fi
}

main_menu() {
  local chosen
  chosen=$(printf '%s\n' "Wi-Fi Connections" "Ethernet Connections" "VPN Connections" |
    "$WOFI" --show dmenu -i --prompt "Network Menu:" -dmenu -lines 3 -width 300 -height 150)
  case "$chosen" in
  "Wi-Fi Connections") wifi_menu ;;
  "Ethernet Connections") ethernet_menu ;;
  "VPN Connections") vpn_menu ;;
  esac
}

check_dependencies

case "${1:-}" in
--menu) main_menu ;;
*) echo "Usage: $0 --menu"; exit 1 ;;
esac
