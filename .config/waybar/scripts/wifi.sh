#!/usr/bin/env bash
set -euo pipefail # Added for robustness: Exit on unset variables, non-zero exit codes, and pipe failures

# Network management script for Waybar using nmcli and Wofi.
# Handles Wi-Fi, Ethernet, and VPN connections.

# --- Configuration ---
NMCLI="/usr/bin/nmcli"
WOFI="/usr/bin/wofi"
NOTIFY_SEND="/usr/bin/notify-send"

# Define your default Wi-Fi and Ethernet interfaces here
WIFI_IFACE="wlan0" # IMPORTANT: Adjust to your actual Wi-Fi interface name (e.g., wlp3s0)
ETH_IFACE="eth0"  # IMPORTANT: Adjust to your actual Ethernet interface name (e.g., enp0s31f6)

# Check if commands exist
command -v "$NMCLI" >/dev/null || { echo "Error: nmcli not found at $NMCLI"; exit 1; }
command -v "$WOFI" >/dev/null || { echo "Error: wofi not found at $WOFI"; exit 1; }
command -v "$NOTIFY_SEND" >/dev/null || { echo "Error: notify-send not found at $NOTIFY_SEND"; exit 1; }

# --- Helper Functions ---

get_signal_icon() {
  local strength=$1
  if ((strength >= 80)); then echo "󰤨";
  elif ((strength >= 60)); then echo "󰤥";
  elif ((strength >= 40)); then echo "󰤢";
  elif ((strength >= 20)); then echo "󰤟";
  else echo "󰤯"; fi
}

get_vpn_icon() {
  local state=$1
  if [[ "$state" == "connected" ]]; then echo "🔒"; # Connected lock
  elif [[ "$state" == "connecting" ]]; then echo "󰌌"; # Spin/connecting
  else echo " "; fi # Disconnected/unlocked icon (changed from "unlock" to a symbol)
}

# Function for nmcli actions (success/fail notification, no output for variable capture)
# Returns 0 on success, 1 on failure.
nmcli_action_and_notify() {
    local cmd_output
    if ! cmd_output=$($NMCLI "$@" 2>&1); then
        if echo "$cmd_output" | grep -q "No reason given"; then
            $NOTIFY_SEND "Network Error" "Action failed (no reason given). Check 'journalctl -u NetworkManager -u iwd' for details."
        else
            $NOTIFY_SEND "Network Error" "Action failed: $cmd_output"
        fi
        return 1
    fi
    return 0 # Success
}

# Function for nmcli commands where output is intended to be captured for variables.
# Returns 0 on success, 1 on failure. On success, it prints the command's stdout/stderr.
nmcli_capture_or_notify_and_fail() {
    local cmd_output
    if ! cmd_output=$($NMCLI "$@" 2>&1); then
        if echo "$cmd_output" | grep -q "No reason given"; then
            $NOTIFY_SEND "Network Error" "Data retrieval failed (no reason given). Check 'journalctl -u NetworkManager -u iwd' for details."
        else
            $NOTIFY_SEND "Network Error" "Data retrieval failed: $cmd_output"
        fi
        return 1
    fi
    echo "$cmd_output" # Return captured stdout/stderr
    return 0
}


# --- Main Functions ---

# --- Wi-Fi Menu Logic ---
wifi_menu() {
    $NOTIFY_SEND "Wi-Fi" "Fetching available networks..."

    local current_wifi_state_raw=$(nmcli_capture_or_notify_and_fail -t -f WIFI g)
    local current_wifi_state=""
    if [[ "$?" -eq 0 ]]; then
        current_wifi_state="$current_wifi_state_raw"
    fi

    # Ensure Wi-Fi is enabled for scanning/connecting
    if [[ "$current_wifi_state" != "enabled" ]]; then
        nmcli_action_and_notify radio wifi on &>/dev/null
        sleep 0.5 # Give it a moment to enable
        # Re-check state after attempting to enable
        current_wifi_state=$(nmcli_capture_or_notify_and_fail -t -f WIFI g)
        if [[ "$?" -ne 0 || "$current_wifi_state" != "enabled" ]]; then
            $NOTIFY_SEND "Wi-Fi Error" "Failed to enable Wi-Fi. Cannot scan for networks."
            exit 1
        fi
    fi

    local wifi_list_raw=$(nmcli_capture_or_notify_and_fail -t -f ACTIVE,SSID,SIGNAL dev wifi)
    local connected_ssid=""
    local connected_signal=""
    local connected_icon=""
    local disconnect_option=""

    if [[ "$?" -eq 0 && -n "$wifi_list_raw" ]]; then
        readarray -t current_conn_info <<<"$(echo "$wifi_list_raw" | awk -F: '$1 == "yes" {print $2, $3}')"
        if [[ ${#current_conn_info[@]} -gt 0 ]]; then
            connected_ssid=$(echo "${current_conn_info[0]}" | cut -d' ' -f1 | xargs) # xargs to trim whitespace
            connected_signal=$(echo "${current_conn_info[0]}" | cut -d' ' -f2 | xargs)
            connected_icon=$(get_signal_icon "$connected_signal")
            disconnect_option="󰐥 Disconnect from $connected_ssid ($connected_signal%)" # Changed to lock icon for consistency
        fi
    else
        $NOTIFY_SEND "Wi-Fi Error" "Failed to get current Wi-Fi status or scan networks."
        # Don't exit, allow menu to still show toggle options if scan failed but radio is on.
    fi

    local saved_connections_raw=$(nmcli_capture_or_notify_and_fail -t -f NAME connection show)
    local saved_connections=""
    if [[ "$?" -eq 0 ]]; then
        saved_connections="$saved_connections_raw"
    fi

    local scan_output=$(nmcli_capture_or_notify_and_fail -t -f SSID,SECURITY,SIGNAL device wifi list)
    if [[ "$?" -ne 0 ]]; then
        $NOTIFY_SEND "Wi-Fi Error" "Failed to scan for networks. Is Wi-Fi enabled and device available?"
        exit 1 # Exit if scan specifically failed, as no networks can be listed for connection
    fi

    local wifi_list=$(echo "$scan_output" | awk -F: '
    {
      if ($1 == "") next;
      icon = ($2 ~ /WPA|WPA2|WPA3|WEP/) ? "" : "";
      printf "%s %s (%s%%)\n", icon, $1, $3;
    }' | sort -k2 -r)

    local toggle_option="󰖪 Disable Wi-Fi"
    if [[ "$current_wifi_state" != "enabled" ]]; then
        toggle_option="󰖩 Enable Wi-Fi"
    fi
    local hidden_option="󰐗 Connect to Hidden Network"

    local wofi_options="$toggle_option\n$hidden_option"
    if [[ -n "$disconnect_option" ]]; then wofi_options="$disconnect_option\n$wofi_options"; fi
    wofi_options="$wofi_options\n$wifi_list"

    local chosen_network=$(
        echo -e "$wofi_options" | uniq |
        $WOFI --show dmenu -i --prompt "Wi-Fi SSID:" \
              -dmenu -lines 10 -columns 1 --width 400 --height 300 \
              -location 0 -x 0 -y 0 --allow-markup
    )

    [[ -z "$chosen_network" ]] && exit 0

    case "$chosen_network" in
    "󰖩 Enable Wi-Fi") nmcli_action_and_notify radio wifi on && $NOTIFY_SEND "Wi-Fi" "Wi-Fi Enabled." ;;
    "󰖪 Disable Wi-Fi") nmcli_action_and_notify radio wifi off && $NOTIFY_SEND "Wi-Fi" "Wi-Fi Disabled." ;;
    "󰐥 Disconnect from "*") # Updated pattern for new icon
        local ssid_to_disconnect=$(echo "$chosen_network" | sed -E 's/󰐥 Disconnect from (.+) \(.+\)/\1/' | xargs)
        nmcli_action_and_notify connection down "$ssid_to_disconnect" && $NOTIFY_SEND "Wi-Fi" "Disconnected from \"$ssid_to_disconnect\"."
        ;;
    "$hidden_option")
        local ssid=$($WOFI --show dmenu --prompt "Enter Hidden SSID:")
        [[ -z "$ssid" ]] && exit 0
        local password=$($WOFI --show dmenu --prompt "Enter Password (leave empty if open):")
        if [[ -n "$password" ]]; then
            nmcli_action_and_notify device wifi connect "$ssid" password "$password" hidden yes && $NOTIFY_SEND "Wi-Fi" "Connected to hidden network \"$ssid\"."
        else
            nmcli_action_and_notify device wifi connect "$ssid" hidden yes && $NOTIFY_SEND "Wi-Fi" "Connected to hidden network \"$ssid\" (Open)."
        fi
        ;;
    *)
        local ssid_to_connect=$(echo "$chosen_network" | sed -E 's/^[^\ ]+ (.+) \([0-9]+%\)$/\1/' | xargs) # Robust regex for icon + ssid (strength)
        local password_required=false
        if echo "$chosen_network" | grep -q ""; then password_required=true; fi

        if [[ "$password_required" == true ]]; then
            local password=$($WOFI --show dmenu --prompt "Enter Password for \"$ssid_to_connect\":")
            [[ -z "$password" ]] && $NOTIFY_SEND "Wi-Fi" "Connection cancelled: No password provided." && exit 0
        fi

        if echo "$saved_connections" | grep -Fxq "$ssid_to_connect"; then
            if ! nmcli_action_and_notify connection up id "$ssid_to_connect"; then
                if [[ "$password_required" == true ]]; then
                    $NOTIFY_SEND "Wi-Fi" "Connection failed. Retrying with new password."
                    if nmcli_action_and_notify connection delete "$ssid_to_connect"; then
                        nmcli_action_and_notify device wifi connect "$ssid_to_connect" password "$password" && $NOTIFY_SEND "Wi-Fi" "Connected to \"$ssid_to_connect\" (re-added)."
                    fi
                else
                    nmcli_action_and_notify device wifi connect "$ssid_to_connect" && $NOTIFY_SEND "Wi-Fi" "Connected to \"$ssid_to_connect\" (re-attempted)."
                fi
            fi
        else
            if [[ "$password_required" == true ]]; then
                nmcli_action_and_notify device wifi connect "$ssid_to_connect" password "$password" && $NOTIFY_SEND "Wi-Fi" "Connected to \"$ssid_to_connect\"."
            else
                nmcli_action_and_notify device wifi connect "$ssid_to_connect" && $NOTIFY_SEND "Wi-Fi" "Connected to \"$ssid_to_connect\"."
            fi
        fi
        ;;
    esac
}

# --- Ethernet Menu Logic ---
ethernet_menu() {
    local eth_state_raw=$(nmcli_capture_or_notify_and_fail -t -f DEVICE,STATE dev)
    local eth_state=""
    if [[ "$?" -eq 0 && -n "$eth_state_raw" ]]; then
        eth_state=$(echo "$eth_state_raw" | awk -F: -v iface="$ETH_IFACE" '$1 == iface {print $2}')
    else
        $NOTIFY_SEND "Ethernet Error" "Failed to get Ethernet device state."
    fi

    local eth_conns_raw=$(nmcli_capture_or_notify_and_fail -t -f NAME,DEVICE connection show)
    local eth_conns=""
    if [[ "$?" -eq 0 && -n "$eth_conns_raw" ]]; then
        eth_conns=$(echo "$eth_conns_raw" | grep -F "$ETH_IFACE" | cut -d: -f1)
    fi

    local wofi_options=""
    # Check current state to add "Disconnect" option
    if [[ "$eth_state" == "connected" || "$eth_state" == "connecting" ]]; then
        wofi_options+="󰐥 Disconnect Ethernet\n" # Using same disconnect icon
    fi
    wofi_options+="󰈀 Enable Ethernet (DHCP)\n󰈀 Disable Ethernet"


    local chosen_action=$(
        echo -e "$wofi_options" | $WOFI --show dmenu -i --prompt "Ethernet Action:" \
              -dmenu -lines 5 -columns 1 --width 300 --height 150 \
              -location 0 -x 0 -y 0 --allow-markup
    )
    [[ -z "$chosen_action" ]] && exit 0

    case "$chosen_action" in
        "󰈀 Enable Ethernet (DHCP)")
            # This attempts to activate an existing profile or create a new DHCP one
            nmcli_action_and_notify device connect "$ETH_IFACE" && $NOTIFY_SEND "Ethernet" "Enabled and connecting via Ethernet."
            ;;
        "󰈀 Disable Ethernet")
            nmcli_action_and_notify device disconnect "$ETH_IFACE" && $NOTIFY_SEND "Ethernet" "Disabled Ethernet."
            ;;
        "󰐥 Disconnect Ethernet") # Updated pattern for new icon
            local active_eth_conn_raw=$(nmcli_capture_or_notify_and_fail -t -f NAME,DEVICE connection show --active)
            local active_eth_conn=""
            if [[ "$?" -eq 0 && -n "$active_eth_conn_raw" ]]; then
                active_eth_conn=$(echo "$active_eth_conn_raw" | grep -F "$ETH_IFACE" | cut -d: -f1)
            fi

            if [[ -n "$active_eth_conn" ]]; then
                nmcli_action_and_notify connection down "$active_eth_conn" && $NOTIFY_SEND "Ethernet" "Disconnected from \"$active_eth_conn\"."
            else
                $NOTIFY_SEND "Ethernet" "No active Ethernet connection to disconnect."
            fi
            ;;
    esac
}

# --- VPN Status for Waybar Display ---
vpn_status_display() {
    local vpn_active_name_raw=$(nmcli_capture_or_notify_and_fail -t -f name,type connection show --active)
    local vpn_active_name=""
    if [[ "$?" -eq 0 && -n "$vpn_active_name_raw" ]]; then
        vpn_active_name=$(echo "$vpn_active_name_raw" | awk -F: '$2 == "vpn" {print $1}')
    fi

    local vpn_state="disconnected" # Default state

    if [[ -n "$vpn_active_name" ]]; then
        vpn_state="connected"
        echo "$(get_vpn_icon "$vpn_state") $vpn_active_name"
    else
        echo "$(get_vpn_icon "$vpn_state") VPN"
    fi
}

# --- VPN Connection Menu ---
vpn_menu() {
    $NOTIFY_SEND "VPN" "Fetching VPN connections..."

    local vpn_list_raw=$(nmcli_capture_or_notify_and_fail -t -f NAME,TYPE connection show)
    local vpn_list=""
    if [[ "$?" -eq 0 && -n "$vpn_list_raw" ]]; then
        vpn_list=$(echo "$vpn_list_raw" | awk -F: '$2 == "vpn" {print $1}')
    fi

    local active_vpn_raw=$(nmcli_capture_or_notify_and_fail -t -f name,type connection show --active)
    local active_vpn=""
    if [[ "$?" -eq 0 && -n "$active_vpn_raw" ]]; then
        active_vpn=$(echo "$active_vpn_raw" | awk -F: '$2 == "vpn" {print $1}')
    fi

    local wofi_options=""

    if [[ -n "$active_vpn" ]]; then
        wofi_options+="󰐥 Disconnect VPN\n"
    fi

    while IFS= read -r line; do
        if [[ "$line" != "$active_vpn" ]]; then
            wofi_options+="🔒 Connect $line\n"
        fi
    done <<<"$vpn_list"

    # Remove trailing newline
    wofi_options="${wofi_options%$'\n'}"

    if [[ -z "$wofi_options" ]]; then
        $NOTIFY_SEND "VPN" "No VPN connections configured."
        exit 0
    fi

    local chosen_action=$(
        echo -e "$wofi_options" | $WOFI --show dmenu -i --prompt "VPN Action:" \
              -dmenu -lines 10 -columns 1 --width 400 --height 300 \
              -location 0 -x 0 -y 0 --allow-markup
    )

    [[ -z "$chosen_action" ]] && exit 0

    case "$chosen_action" in
        "󰐥 Disconnect VPN")
            if [[ -n "$active_vpn" ]]; then
                nmcli_action_and_notify connection down "$active_vpn" && $NOTIFY_SEND "VPN" "Disconnected from \"$active_vpn\"."
            else
                $NOTIFY_SEND "VPN" "No active VPN to disconnect."
            fi
            ;;
        "🔒 Connect "*")
            local vpn_name_to_connect=$(echo "$chosen_action" | sed 's/🔒 Connect //')
            nmcli_action_and_notify connection up "$vpn_name_to_connect" && $NOTIFY_SEND "VPN" "Connecting to \"$vpn_name_to_connect\"..."
            ;;
    esac
}

# --- Main Script Execution Logic ---
case "$1" in
    --wifi-menu)
        wifi_menu
        ;;
    --toggle-wifi)
        local state_raw=$(nmcli_capture_or_notify_and_fail -t -f WIFI g)
        local state=""
        if [[ "$?" -eq 0 ]]; then
            state="$state_raw"
        fi

        if [[ "$state" == "enabled" ]]; then
            nmcli_action_and_notify radio wifi off && $NOTIFY_SEND "Wi-Fi" "Wi-Fi Disabled."
        elif [[ "$state" == "disabled" ]]; then
            nmcli_action_and_notify radio wifi on && $NOTIFY_SEND "Wi-Fi" "Wi-Fi Enabled."
        else
            $NOTIFY_SEND "Wi-Fi Error" "Could not determine Wi-Fi state for toggle."
        fi
        ;;
    --ethernet-menu)
        ethernet_menu
        ;;
    --vpn-status)
        vpn_status_display
        ;;
    --vpn-menu)
        vpn_menu
        ;;
    *)
        echo "Usage: $(basename "$0") --wifi-menu | --toggle-wifi | --ethernet-menu | --vpn-status | --vpn-menu"
        exit 1
        ;;
esac
