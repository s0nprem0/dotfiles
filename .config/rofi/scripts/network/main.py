import os
import time

from network import common
from network.common import (
    wifi_enable, wifi_disable, ethernet_icon, vpn_icon, back_icon, BACK,
    rofi_menu, notify, error_menu,
    is_wifi_enabled, get_active_wifi, get_public_ip,
    get_active_vpn, nmcli_run, NOTIFY_TITLE, NOTIFY_OK,
)
from network.wifi import wifi_menu
from network.ethernet import ethernet_menu
from network.vpn import vpn_menu


def main_menu() -> None:
    wifi_status = "On" if is_wifi_enabled() else "Off"
    active_wifi = get_active_wifi()
    wifi_detail = active_wifi if active_wifi else wifi_status
    active_vpn = get_active_vpn()
    vpn_detail = f"({active_vpn})" if active_vpn else ""

    # Public IP: non-blocking — read file cache, background refresh
    pub_ip = None
    try:
        mtime = os.path.getmtime(common.PUBLIC_IP_CACHE)
        if time.time() - mtime < 60:
            with open(common.PUBLIC_IP_CACHE) as f:
                pub_ip = f.read().strip() or None
    except Exception:
        pass
    if not pub_ip:
        import threading
        threading.Thread(target=get_public_ip, daemon=True).start()

    options: list[str] = []
    option_values: dict[str, str] = {}

    wifi_label = f"{wifi_enable}  Wi-Fi  ({wifi_detail})"
    options.append(wifi_label)
    option_values[wifi_label] = "wifi"

    eth_label = f"{ethernet_icon}  Ethernet"
    options.append(eth_label)
    option_values[eth_label] = "ethernet"

    vpn_label = f"{vpn_icon}  VPN  {vpn_detail}"
    options.append(vpn_label)
    option_values[vpn_label] = "vpn"

    if pub_ip:
        ip_label = f"󰩟  Public IP:  {pub_ip}"
        options.append(ip_label)
        option_values[ip_label] = ""

    options.append(f"{back_icon}  Exit")
    option_values[options[-1]] = BACK

    chosen = rofi_menu(options, " 󰤨  Network")
    if not chosen:
        return

    selection = option_values.get(chosen)
    if not selection:
        return

    if selection == "wifi":
        wifi_menu()
    elif selection == "ethernet":
        ethernet_menu()
    elif selection == "vpn":
        vpn_menu()
