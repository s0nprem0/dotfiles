from network.common import (
    wifi_enable, ethernet_icon, vpn_icon,
    rofi_menu, is_wifi_enabled, get_active_wifi, get_public_ip,
    get_active_vpn,
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
    pub_ip = get_public_ip()

    options = [
        f"{wifi_enable}  Wi-Fi  ({wifi_detail})",
        f"{ethernet_icon}  Ethernet",
        f"{vpn_icon}  VPN  {vpn_detail}",
    ]
    if pub_ip:
        options.append(f"󰩟  Public IP:  {pub_ip}")

    chosen = rofi_menu(options, " 󰤨  Network")
    if not chosen:
        return

    if "Wi-Fi" in chosen:
        wifi_menu()
    elif "Ethernet" in chosen:
        ethernet_menu()
    elif "VPN" in chosen:
        vpn_menu()


def run() -> None:
    main_menu()
