from network.common import (
    notify, back_icon, BACK,
    disconnect_icon, vpn_icon,
    NOTIFY_TITLE, NOTIFY_OK,
    nmcli_run, rofi_menu, error_menu,
    get_vpn_list, get_active_vpn,
)


def vpn_menu() -> None:
    vpns = get_vpn_list()
    active_vpn = get_active_vpn()
    options: dict[str, str] = {}

    if active_vpn:
        options[f"{disconnect_icon}  Disconnect VPN ({active_vpn})"] = f"DISCONNECT:{active_vpn}"

    for vpn in vpns:
        if vpn != active_vpn:
            options[f"{vpn_icon}  Connect {vpn}"] = f"CONNECT:{vpn}"

    if not options:
        options["  No VPNs configured"] = ""
    options[f"{back_icon}  Back"] = BACK

    chosen = rofi_menu(list(options.keys()), f" {vpn_icon}")
    if not chosen:
        return

    selection = options.get(chosen)
    if not selection:
        return

    if selection.startswith("DISCONNECT:"):
        vpn_name = selection.split(":", 1)[1]
        r = nmcli_run(["connection", "down", "id", vpn_name], want_result=True)
        if isinstance(r, dict) and not r.get("ok"):
            error_menu(f"Failed to disconnect VPN ({vpn_name})", r.get("stderr") or r.get("message", ""))
            vpn_menu()
            return
        notify(title=NOTIFY_TITLE, message=f"VPN disconnected ({vpn_name})", **NOTIFY_OK)
        vpn_menu()
    elif selection.startswith("CONNECT:"):
        vpn_name = selection.split(":", 1)[1]
        r = nmcli_run(["connection", "up", "id", vpn_name], want_result=True)
        if isinstance(r, dict) and not r.get("ok"):
            error_menu(f"Failed to connect VPN ({vpn_name})", r.get("stderr") or r.get("message", ""))
            vpn_menu()
            return
        notify(title=NOTIFY_TITLE, message=f"VPN connected ({vpn_name})", **NOTIFY_OK)
        vpn_menu()
    elif selection == BACK:
        from network.main import main_menu
        main_menu()
