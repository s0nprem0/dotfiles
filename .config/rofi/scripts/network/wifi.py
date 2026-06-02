import re
import subprocess
from typing import Optional

from network import nm_dbus

from network.common import (
    notify, back_icon, BACK,
    shut_lock, open_lock, wifi_enable, wifi_disable, wifi_known,
    connect_icon, forget_icon, disconnect_icon, hidden_icon,
    NOTIFY_TITLE, NOTIFY_OK, NOTIFY_BUSY,
    WifiNetwork,
    TOGGLE_WIFI, CONNECT, FORGET, DISCONNECT, HIDDEN, RESCAN,
    HOTSPOT, STOP_HOTSPOT, SAVED, POWERSAVE,
    signal_bars, nmcli_run,
    rofi_menu, error_menu, confirm_menu, rofi_input, rofi_password, rofi_custom_kb,
    is_wifi_enabled, get_saved_networks, get_active_wifi,
    list_wifi_networks, get_connection_prop,
    get_power_save, check_connectivity,
    CONFIG_DIR,
)
from network.cache import cached, invalidate


# ─── Wi-Fi Toggle ───────────────────────────────────────────────────────────

def toggle_wifi() -> None:
    if is_wifi_enabled():
        r = nmcli_run(["radio", "wifi", "off"], want_result=True)
        if isinstance(r, dict) and not r.get("ok"):
            error_menu("Failed to disable Wi-Fi", r.get("stderr") or r.get("message", ""))
            return
        notify(title=NOTIFY_TITLE, message="Wi-Fi disabled", **NOTIFY_OK)
        invalidate("wifi_on")
        invalidate("networks")
        invalidate("active_ssid")
    else:
        r = nmcli_run(["radio", "wifi", "on"], want_result=True)
        if isinstance(r, dict) and not r.get("ok"):
            error_menu("Failed to enable Wi-Fi", r.get("stderr") or r.get("message", ""))
            return
        notify(title=NOTIFY_TITLE, message="Wi-Fi enabled", **NOTIFY_OK)
        invalidate("wifi_on")
        invalidate("networks")
        invalidate("active_ssid")


# ─── Connection Actions ─────────────────────────────────────────────────────

def connect_existing_network(ssid: str) -> bool:
    notify(title=NOTIFY_TITLE, message=f"Connecting to {ssid}...", **NOTIFY_BUSY)
    result = nmcli_run(["connection", "up", "id", ssid], timeout=20, want_result=True)
    if isinstance(result, dict) and not result.get("ok"):
        emsg = result.get("message") or "Failed to connect."
        errd = result.get("stderr") or result.get("stdout") or str(result)
        error_menu(f"Failed to connect to {ssid}", errd)
        return False
    notify(title=NOTIFY_TITLE, message=f"Connected to {ssid}", **NOTIFY_OK)
    invalidate("active_ssid")
    return True


def connect_new_network(ssid: str, security: Optional[str]) -> bool:
    cmd = ["device", "wifi", "connect", ssid]
    if security and security.startswith("WPA"):
        pwd = rofi_password(f"{shut_lock} Password for {ssid}:")
        if not pwd:
            return False
        cmd += ["password", pwd]
    notify(title=NOTIFY_TITLE, message=f"Connecting to {ssid}...", **NOTIFY_BUSY)
    result = nmcli_run(cmd, timeout=20, want_result=True)
    if isinstance(result, dict) and not result.get("ok"):
        emsg = result.get("message") or "Failed to connect."
        errd = result.get("stderr") or result.get("stdout") or str(result)
        error_menu(f"Failed to connect to {ssid}", errd)
        return False
    notify(title=NOTIFY_TITLE, message=f"Connected to {ssid}", **NOTIFY_OK)
    invalidate("active_ssid")
    return True


def disconnect_wifi() -> None:
    active = get_active_wifi()
    if active:
        r = nmcli_run(["connection", "down", "id", active], want_result=True)
        if isinstance(r, dict) and not r.get("ok"):
            error_menu(f"Failed to disconnect from {active}", r.get("stderr") or r.get("message", ""))
            return
        notify(title=NOTIFY_TITLE, message=f"Disconnected from {active}", **NOTIFY_OK)
        invalidate("active_ssid")


def connect_hidden_network() -> None:
    ssid = rofi_input(f"{hidden_icon} Hidden SSID:")
    if not ssid:
        return
    pwd = rofi_password(f"{shut_lock} Password (leave empty for open):")
    cmd = ["device", "wifi", "connect", ssid, "hidden", "yes"]
    if pwd:
        cmd += ["password", pwd]
    notify(title=NOTIFY_TITLE, message="Connecting to hidden SSID...", **NOTIFY_BUSY)
    result = nmcli_run(cmd, timeout=20, want_result=True)
    if isinstance(result, dict) and not result.get("ok"):
        emsg = result.get("message") or "Failed to connect."
        errd = result.get("stderr") or result.get("stdout") or str(result)
        error_menu(f"Failed to connect to hidden SSID {ssid}", errd)
        return
    notify(title=NOTIFY_TITLE, message=f"Connected to {ssid}", **NOTIFY_OK)
    invalidate("active_ssid")


def forget_network(ssid: str) -> bool:
    result = nmcli_run(["connection", "delete", "id", ssid], want_result=True)
    if isinstance(result, dict) and not result.get("ok"):
        error_menu(f"Failed to forget network {ssid}", result.get("stderr") or result.get("message", ""))
        return False
    notify(title=NOTIFY_TITLE, message=f"Forgot network: {ssid}", **NOTIFY_OK)
    invalidate("networks")
    invalidate("active_ssid")
    return True


# ─── Connection Management ──────────────────────────────────────────────────

def is_auto_connect(ssid: str) -> bool:
    val = get_connection_prop(ssid, "connection.autoconnect")
    return val == "yes" if val else True


def toggle_autoconnect(ssid: str) -> None:
    current = is_auto_connect(ssid)
    new_val = "no" if current else "yes"
    r = nmcli_run(["connection", "modify", "id", ssid, "connection.autoconnect", new_val], want_result=True)
    if isinstance(r, dict) and not r.get("ok"):
        error_menu(f"Failed to toggle auto-connect for {ssid}", r.get("stderr") or r.get("message", ""))
        return
    notify(title=NOTIFY_TITLE, message=f"Auto-connect: {'ON' if new_val == 'yes' else 'OFF'} for {ssid}",
           **NOTIFY_OK)


def toggle_power_save() -> None:
    iface = _get_wifi_iface()
    if not iface:
        return
    current = get_power_save()
    if current is None:
        error_menu("Could not read power save state")
        return
    new_val = "on" if not current else "off"
    r = sudo_run(["iw", "dev", iface, "set", "power_save", new_val])
    if isinstance(r, dict) and not r.get("ok"):
        error_menu("Failed to toggle power saving", r.get("stderr", ""))
        return
    notify(title=NOTIFY_TITLE, message=f"Power saving: {'ON' if new_val == 'on' else 'OFF'}",
           **NOTIFY_OK)
    invalidate("power_save")


def _get_wifi_iface() -> Optional[str]:
    return nm_dbus.get_wifi_iface()


# ─── Sudo helper (uses SUDO_ASKPASS for GUI password) ────────────────────

def sudo_run(cmd: list[str]) -> dict:
    import subprocess
    result = subprocess.run(
        ["sudo", "-A"] + cmd,
        capture_output=True, text=True, timeout=30,
    )
    if result.returncode != 0:
        return {"ok": False, "stderr": result.stderr, "stdout": result.stdout, "returncode": result.returncode}
    return {"ok": True, "stdout": result.stdout.strip()}


# ─── MAC Spoof Menu ──────────────────────────────────────────────────────

def _get_macchanger_state(iface: str) -> str | None:
    r = sudo_run(["macchanger", "--show", iface])
    if not r.get("ok"):
        return None
    out = r.get("stdout", "")
    if "Permanent MAC:" in out:
        return out
    return None


def show_mac_spoof_menu(iface: str) -> None:
    current = _get_macchanger_state(iface)
    opts: list[str] = []
    actions: dict[str, str] = {}
    if current:
        for line in current.splitlines():
            stripped = line.strip()
            if stripped:
                opts.append(_ns(stripped))
        opts.append(_ns(""))

    add = lambda k, v: (opts.append(k), actions.__setitem__(k, v))
    add("  Random MAC", f"MACSET:{iface}:random")
    add("  Random vendor MAC", f"MACSET:{iface}:vendor")
    add("  Custom MAC", f"MACSET:{iface}:custom")
    add("  Reset to permanent", f"MACSET:{iface}:permanent")
    add(f"{back_icon}  {BACK}", "back")

    chosen = rofi_menu(opts, f"󱞩  Spoof MAC — {iface}")
    if not chosen:
        wifi_menu()
        return

    action = actions.get(chosen)
    if not action:
        wifi_menu()
        return

    if action == "back":
        wifi_menu()
        return

    if action.startswith("MACSET:"):
        _, iface_name, mode = action.split(":", 2)
        if mode == "random":
            cmd = ["ip", "link", "set", iface_name, "down"]
            r = sudo_run(cmd)
            if not r.get("ok"):
                error_menu("Failed to bring interface down", r.get("stderr", ""))
                show_mac_spoof_menu(iface)
                return
            r = sudo_run(["macchanger", "-r", iface_name])
            if not r.get("ok"):
                error_menu("MAC spoof failed", r.get("stderr", ""))
                sudo_run(["ip", "link", "set", iface_name, "up"])
                show_mac_spoof_menu(iface)
                return
            sudo_run(["ip", "link", "set", iface_name, "up"])
            new_mac = r.get("stdout", "")
            notify(title=NOTIFY_TITLE, message=f"Random MAC set on {iface_name}", **NOTIFY_OK)
        elif mode == "vendor":
            r = sudo_run(["ip", "link", "set", iface_name, "down"])
            r = sudo_run(["macchanger", "-a", iface_name])
            if not r.get("ok"):
                error_menu("MAC spoof failed", r.get("stderr", ""))
            sudo_run(["ip", "link", "set", iface_name, "up"])
            notify(title=NOTIFY_TITLE, message=f"Vendor MAC set on {iface_name}", **NOTIFY_OK)
        elif mode == "custom":
            # Prompt for custom MAC in rofi
            result = subprocess.run(
                f"echo | rofi -dmenu -p 'Custom MAC ({iface_name}):' -theme {CONFIG_DIR / 'rofi' / 'input.rasi'}",
                shell=True, text=True, capture_output=True
            ).stdout.strip()
            if not result:
                show_mac_spoof_menu(iface)
                return
            mac = result.strip().lower()
            # Validate MAC format (xx:xx:xx:xx:xx:xx)
            if not re.match(r'^([0-9a-f]{2}:){5}[0-9a-f]{2}$', mac):
                error_menu("Invalid MAC format", f"Expected: 00:11:22:33:44:55\nGot: {mac}")
                show_mac_spoof_menu(iface)
                return
            sudo_run(["ip", "link", "set", iface_name, "down"])
            r = sudo_run(["macchanger", "-m", mac, iface_name])
            if not r.get("ok"):
                error_menu("Failed to set custom MAC", r.get("stderr", ""))
                sudo_run(["ip", "link", "set", iface_name, "up"])
                show_mac_spoof_menu(iface)
                return
            sudo_run(["ip", "link", "set", iface_name, "up"])
            notify(title=NOTIFY_TITLE, message=f"Custom MAC {mac} set on {iface_name}", **NOTIFY_OK)
        elif mode == "permanent":
            sudo_run(["ip", "link", "set", iface_name, "down"])
            r = sudo_run(["macchanger", "-p", iface_name])
            if not r.get("ok"):
                error_menu("MAC reset failed", r.get("stderr", ""))
            sudo_run(["ip", "link", "set", iface_name, "up"])
            notify(title=NOTIFY_TITLE, message=f"MAC reset to permanent on {iface_name}", **NOTIFY_OK)
        invalidate("networks")
        invalidate("active_ssid")
        wifi_menu()


# ─── Non-Selectable Row Helper ─────────────────────────────────────────────

def _ns(label: str) -> str:
    return f"{label}\0nonselectable\x1ftrue"


# ─── Band / MAC / Priority ────────────────────────────────────────────────

def get_band_preference(ssid: str) -> str:
    val = get_connection_prop(ssid, "802-11-wireless.band")
    return val if val else "auto"


def cycle_band(network: WifiNetwork) -> None:
    ssid = network.ssid
    current = get_band_preference(ssid)
    order = {"auto": "a", "a": "bg", "bg": "auto"}
    new_band = order.get(current, "auto")
    r = nmcli_run(["connection", "modify", "id", ssid, "802-11-wireless.band", new_band], want_result=True)
    if isinstance(r, dict) and not r.get("ok"):
        error_menu("Failed to set band preference", r.get("stderr") or r.get("message", ""))
        show_network_actions(network)
        return
    label = {"auto": "Auto", "a": "5 GHz", "bg": "2.4 GHz"}
    notify(title=NOTIFY_TITLE, message=f"Band: {label.get(new_band, new_band)} for {ssid}",
           **NOTIFY_OK)
    show_network_actions(network)


def get_mac_mode(ssid: str) -> str:
    val = get_connection_prop(ssid, "802-11-wireless.cloned-mac-address")
    return val if val else "permanent"


_MAC_RE = r'^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$'


def _is_custom_mac(val: str) -> bool:
    return bool(re.match(_MAC_RE, val))


def cycle_mac(network: WifiNetwork) -> None:
    ssid = network.ssid
    current = get_mac_mode(ssid)
    if _is_custom_mac(current):
        new_mode = "permanent"
    else:
        order = {"permanent": "random", "random": "stable", "stable": "permanent"}
        new_mode = order.get(current, "permanent")
    r = nmcli_run(["connection", "modify", "id", ssid, "802-11-wireless.cloned-mac-address", new_mode], want_result=True)
    if isinstance(r, dict) and not r.get("ok"):
        error_menu("Failed to set MAC mode", r.get("stderr") or r.get("message", ""))
        show_network_actions(network)
        return
    notify(title=NOTIFY_TITLE, message=f"MAC: {new_mode} for {ssid}", **NOTIFY_OK)
    show_network_actions(network)


def set_custom_mac(network: WifiNetwork) -> None:
    ssid = network.ssid
    current = get_mac_mode(ssid)
    default = current if _is_custom_mac(current) else ""
    raw = rofi_input(f"  MAC for {ssid}", default)
    if not raw:
        show_network_actions(network)
        return
    mac = raw.strip().lower()
    if not re.match(_MAC_RE, mac):
        error_menu("Invalid MAC — use format 00:11:22:33:44:55")
        show_network_actions(network)
        return
    r = nmcli_run(["connection", "modify", "id", ssid,
                    "802-11-wireless.cloned-mac-address", mac], want_result=True)
    if isinstance(r, dict) and not r.get("ok"):
        error_menu(f"Failed to set MAC for {ssid}", r.get("stderr") or r.get("message", ""))
        show_network_actions(network)
        return
    notify(title=NOTIFY_TITLE, message=f"MAC set to {mac} for {ssid}", **NOTIFY_OK)
    show_network_actions(network)


def reset_mac(network: WifiNetwork) -> None:
    ssid = network.ssid
    if not confirm_menu(f"Reset MAC to permanent for {ssid}?"):
        show_network_actions(network)
        return
    r = nmcli_run(["connection", "modify", "id", ssid,
                    "802-11-wireless.cloned-mac-address", ""], want_result=True)
    if isinstance(r, dict) and not r.get("ok"):
        error_menu(f"Failed to reset MAC for {ssid}", r.get("stderr") or r.get("message", ""))
        show_network_actions(network)
        return
    notify(title=NOTIFY_TITLE, message=f"MAC reset to permanent for {ssid}", **NOTIFY_OK)
    show_network_actions(network)


def get_autoconnect_priority(ssid: str) -> int:
    val = get_connection_prop(ssid, "connection.autoconnect-priority")
    return int(val) if val and val.isdigit() else 0


def cycle_priority(network: WifiNetwork) -> None:
    ssid = network.ssid
    current = get_autoconnect_priority(ssid)
    values = [0, 5, 10, 20, 50, 100]
    idx = (values.index(current) + 1) % len(values) if current in values else 0
    new_prio = values[idx]
    r = nmcli_run(["connection", "modify", "id", ssid, "connection.autoconnect-priority", str(new_prio)], want_result=True)
    if isinstance(r, dict) and not r.get("ok"):
        error_menu("Failed to set priority", r.get("stderr") or r.get("message", ""))
        show_network_actions(network)
        return
    notify(title=NOTIFY_TITLE, message=f"Priority: {new_prio} for {ssid}", **NOTIFY_OK)
    show_network_actions(network)


# ─── DNS ─────────────────────────────────────────────────────────────────────

def get_dns_servers(ssid: str) -> list[str]:
    dns = get_connection_prop(ssid, "ipv4.dns")
    return [s.strip() for s in dns.split(",") if s.strip()]


def set_dns_servers(network: WifiNetwork) -> None:
    ssid = network.ssid
    current = get_dns_servers(ssid)
    default = ", ".join(current) if current else ""
    raw = rofi_input(f"  DNS for {ssid} (comma-sep, empty=auto):", default)
    if raw == default:
        show_network_actions(network)
        return
    servers = [s.strip() for s in raw.split(",") if s.strip()]
    if servers:
        dns_str = " ".join(servers)
        r = nmcli_run(["connection", "modify", "id", ssid, "ipv4.dns", dns_str,
                        "ipv4.ignore-auto-dns", "yes"], want_result=True)
    else:
        r = nmcli_run(["connection", "modify", "id", ssid, "ipv4.dns", "",
                        "ipv4.ignore-auto-dns", "no"], want_result=True)
    if isinstance(r, dict) and not r.get("ok"):
        error_menu(f"Failed to set DNS for {ssid}", r.get("stderr") or r.get("message", ""))
        show_network_actions(network)
        return
    label = " ".join(servers) if servers else "auto"
    notify(title=NOTIFY_TITLE, message=f"DNS: {label} for {ssid}", **NOTIFY_OK)
    show_network_actions(network)


# ─── Connection Details ─────────────────────────────────────────────────────

def show_connection_details(network: WifiNetwork) -> None:
    opts = [_ns(f"SSID:  {network.ssid}")]
    iface = get_connection_prop(network.ssid, "connection.interface-name")
    if not iface:
        iface = nm_dbus.get_wifi_iface() or ""
    aconnect = get_connection_prop(network.ssid, "connection.autoconnect")
    if aconnect:
        opts.append(_ns(f"Auto-connect:  {aconnect}"))
    ipmethod = get_connection_prop(network.ssid, "ipv4.method")
    if ipmethod:
        opts.append(_ns(f"IP method:  {ipmethod}"))
    if iface:
        opts.append(_ns(f"Interface:  {iface}"))
        dev = nm_dbus.get_device_info(iface)
        if dev:
            if dev.get("mac"):
                opts.append(_ns(f"MAC:  {dev['mac']}"))
            if dev.get("ip"):
                opts.append(_ns(f"IP:  {dev['ip']}"))
            if dev.get("gateway"):
                opts.append(_ns(f"Gateway:  {dev['gateway']}"))
            if dev.get("dns"):
                opts.append(_ns(f"DNS:  {dev['dns']}"))
            if dev.get("speed"):
                opts.append(_ns(f"Speed:  {dev['speed']} Mb/s"))
    opts.append(f"{back_icon}  Back")
    rofi_menu(opts, prompt=f"{wifi_enable} Details", selected_row=len(opts) - 1)
    show_network_actions(network)


def show_wifi_info_menu(network: WifiNetwork) -> None:
    ap = nm_dbus.get_wifi_ap_info(network.ssid)

    opts = [_ns(f"SSID:  {network.ssid}")]
    if ap:
        opts.append(_ns(f"Security:  {ap.get('security') or 'Open'}"))
        opts.append(_ns(f"Signal:  {ap.get('signal', 0)}%  {signal_bars(ap.get('signal', 0))}"))
        opts.append(_ns(f"Channel:  {ap.get('channel', '?')}  ({ap.get('frequency', '?')} MHz)"))
        opts.append(_ns(f"Rate:  {ap.get('rate', '?')}"))
        if ap.get("bssid"):
            opts.append(_ns(f"BSSID:  {ap['bssid']}"))
    else:
        opts.append(_ns(f"Security:  {network.security or 'Open'}"))
        opts.append(_ns(f"Signal:  {network.signal}%  {signal_bars(network.signal)}"))
    if network.saved:
        opts.append(_ns(f"Saved:  Yes"))
    opts.append(f"{back_icon}  Back")
    rofi_menu(opts, prompt=f"{wifi_enable} Info", selected_row=len(opts) - 1)


# ─── Network Action Menu ────────────────────────────────────────────────────

def show_network_actions(network: WifiNetwork, active_ssid: Optional[str] = None) -> None:
    if active_ssid is None:
        active_ssid = cached("active_ssid", get_active_wifi, ttl=2)

    is_connected = network.ssid == active_ssid
    title = f"{wifi_enable}  {network.ssid}"
    if network.saved:
        title += f"  {wifi_known}"
    if is_connected:
        title += "  "

    actions: dict[str, str] = {}
    if not is_connected:
        actions[f"{connect_icon}  {CONNECT}"] = "connect"
    actions[f"  Info"] = "info"
    if network.saved:
        actions[f"{forget_icon}  {FORGET}"] = "forget"
    if is_connected:
        actions[f"  Details"] = "details"
    if network.saved:
        auto = is_auto_connect(network.ssid)
        icon = "" if auto else ""
        actions[f"{icon}  Auto-connect: {'On' if auto else 'Off'}"] = "autoconnect"
        band = get_band_preference(network.ssid)
        bl = {"auto": "Auto", "a": "5 GHz", "bg": "2.4 GHz"}
        actions[f"  Band: {bl.get(band, band)}"] = "band"
        mac = get_mac_mode(network.ssid)
        label = "custom" if _is_custom_mac(mac) else mac
        actions[f"  MAC: {label}"] = "mac"
        actions["  Set custom MAC"] = "setmac"
        if _is_custom_mac(mac):
            actions["  Reset MAC to permanent"] = "resetmac"
        prio = get_autoconnect_priority(network.ssid)
        actions[f"  Priority: {prio}"] = "priority"
        dns = get_dns_servers(network.ssid)
        dns_label = " ".join(dns) if dns else "auto"
        actions[f"  DNS: {dns_label}"] = "dns"
    actions[f"{back_icon}  {BACK}"] = "back"

    chosen = rofi_menu(list(actions.keys()), title)
    if not chosen:
        return

    action = actions.get(chosen)

    if action == "back":
        wifi_menu()
    elif action == "connect":
        if network.saved:
            ok = connect_existing_network(network.ssid)
        else:
            ok = connect_new_network(network.ssid, network.security)
        if ok:
            wifi_menu()
        else:
            show_network_actions(network)
    elif action == "forget":
        if confirm_menu(f"{forget_icon} Forget {network.ssid}?"):
            ok = forget_network(network.ssid)
            if ok:
                wifi_menu()
            else:
                show_network_actions(network)
        else:
            show_network_actions(network)
    elif action == "info":
        show_wifi_info_menu(network)
        show_network_actions(network)
    elif action == "details":
        show_connection_details(network)
    elif action == "autoconnect":
        toggle_autoconnect(network.ssid)
        show_network_actions(network)
    elif action == "band":
        cycle_band(network)
    elif action == "mac":
        cycle_mac(network)
    elif action == "setmac":
        set_custom_mac(network)
    elif action == "resetmac":
        reset_mac(network)
    elif action == "priority":
        cycle_priority(network)
    elif action == "dns":
        set_dns_servers(network)


# ─── Saved Networks Menu ───────────────────────────────────────────────────

def saved_networks_menu() -> None:
    saved = [s for s in get_saved_networks() if s]
    if not saved:
        notify(title=NOTIFY_TITLE, message="No saved Wi-Fi networks", urgency="low")
        return

    active_ssid = cached("active_ssid", get_active_wifi, ttl=2)
    options = {}
    for ssid in saved:
        active_tag = " " if ssid == active_ssid else ""
        offline = "" if ssid == active_ssid else "  (offline)"
        options[f"{active_tag}{wifi_known}  {ssid}{offline}"] = ssid
    options[f"{back_icon}  Back"] = BACK

    chosen = rofi_menu(list(options.keys()), f"{wifi_known}  Saved Networks")
    if not chosen:
        return

    selection = options.get(chosen)
    if not selection:
        return

    if selection == BACK:
        return
    else:
        network = WifiNetwork(ssid=selection, security=None, signal=0,
                              saved=True, visible=selection in list_wifi_networks(no_rescan=True), band="")
        show_network_actions(network)


# ─── Wi-Fi Menu ─────────────────────────────────────────────────────────────

def wifi_menu() -> None:
    wifi_on = cached("wifi_on", is_wifi_enabled, ttl=2)
    networks = cached("networks", lambda: list_wifi_networks() if wifi_on else {}, ttl=2)
    active_ssid = cached("active_ssid", get_active_wifi, ttl=2)

    if wifi_on and (not networks or "~scanning~" in networks):
        notify(title=NOTIFY_TITLE, message="Scanning for networks...", expire_time=6_000)
        networks = list_wifi_networks(no_rescan=False)
        active_ssid = get_active_wifi()
        invalidate("networks")
        invalidate("active_ssid")

    option_rows: list[str] = []
    option_values: dict[str, str] = {}
    active_rows: list[int] = []
    urgent_rows: list[int] = []

    def add_option(label: str, value: str, *, active: bool = False, urgent: bool = False,
                   selectable: bool = True) -> None:
        row = label
        if not selectable:
            row = f"{label}\0nonselectable\x1ftrue"

        option_rows.append(row)

        if selectable:
            option_values[label] = value

        idx = len(option_rows) - 1
        if active:
            active_rows.append(idx)
        if urgent:
            urgent_rows.append(idx)

    if wifi_on:
        add_option("󰅬  Actions", "", selectable=False)

        add_option(f"{wifi_disable}  Disable Wi-Fi", TOGGLE_WIFI)

        if active_ssid:
            add_option(f"{disconnect_icon}  Disconnect  ({active_ssid})", DISCONNECT)

        add_option(f"{hidden_icon}  Connect to Hidden Network", HIDDEN)

        add_option("󰋁  Create Hotspot", HOTSPOT, active=True)

        from network.hotspot import is_hotspot_active
        if is_hotspot_active():
            add_option("󰤂  Stop Hotspot", STOP_HOTSPOT)

        add_option(f"{wifi_known}  Saved Networks", SAVED)

        add_option("󱞩  MAC Spoof", "MACSPOOF")

        add_option("  Rescan", RESCAN)

        ps = cached("power_save", get_power_save, ttl=5)
        if ps is not None:
            ps_icon = "" if ps else ""
            add_option(f"{ps_icon}  Power Save: {'On' if ps else 'Off'}", POWERSAVE)

        conn = cached("connectivity", check_connectivity, ttl=5)
        if conn in ("full", "limited", "portal", "none"):
            ci = {"full": "󰤨", "limited": "󰤢", "portal": "󰤦", "none": "󰤭"}
            is_bad = conn in ("limited", "portal", "none")
            add_option(f"{ci.get(conn, '󰤯')}  Status: {conn}", "", urgent=is_bad, selectable=False)
            if conn == "portal":
                add_option("󰖐  Open Captive Portal Login", "OPEN_PORTAL")

        add_option("󰤨  Networks", "", selectable=False)

        if "~scanning~" in networks:
            add_option("󰓨  Scanning...", "", selectable=False)
        else:
            sorted_networks = sorted(
                networks.values(),
                key=lambda n: (
                    n.ssid != active_ssid,
                    not n.saved,
                    -n.signal,
                    n.ssid.lower(),
                ),
            )
            for n in sorted_networks:
                icon = wifi_known if n.saved else (
                    shut_lock if n.security and n.security.startswith("WPA") else open_lock
                )
                active_tag = f" " if n.ssid == active_ssid else ""
                band_tag = f" {n.band}G  " if n.band else "  "
                label = f"{active_tag}{icon}  {signal_bars(n.signal)} {n.signal:>3}%  {n.ssid}"
                if n.band:
                    label += f"  {n.band}"
                add_option(label, n.ssid)
    else:
        add_option(f"{wifi_enable}  Enable Wi-Fi", TOGGLE_WIFI)
        add_option(f"{wifi_known}  Saved Networks", SAVED)

    add_option(f"{back_icon}  Back", BACK)

    chosen, raw = rofi_menu(option_rows, f" {wifi_enable}",
                            selected_row=0,
                            active_rows=active_rows or None,
                            urgent_rows=urgent_rows or None,
                            return_raw=True)  # type: ignore
    if not chosen:
        return

    if chosen.startswith("Error:"):
        return

    kb = rofi_custom_kb(raw)
    if kb != -1:
        if wifi_on and kb == 1:  # Ctrl+r → rescan
            invalidate("networks")
            invalidate("active_ssid")
            notify(title=NOTIFY_TITLE, message="Restarted scanning...", expire_time=4000)
            wifi_menu()
        elif kb == 2:  # Ctrl+t → toggle wifi
            toggle_wifi()
            wifi_menu()
        elif kb == 3 and wifi_on:  # Ctrl+h → create hotspot
            from network.hotspot import create_hotspot
            create_hotspot()
            wifi_menu()
        elif kb == 4:  # Ctrl+s → saved networks
            saved_networks_menu()
        elif kb == 5 and wifi_on:  # Ctrl+m → MAC spoof
            iface = _get_wifi_iface()
            if iface:
                show_mac_spoof_menu(iface)
        return

    selection = option_values.get(chosen)
    if not selection:
        return

    if selection == TOGGLE_WIFI:
        toggle_wifi()
        wifi_menu()
    elif selection == BACK:
        from network.main import main_menu
        main_menu()
    elif selection == "MACSPOOF":
        iface = _get_wifi_iface()
        if iface:
            show_mac_spoof_menu(iface)
    elif selection == DISCONNECT:
        disconnect_wifi()
        wifi_menu()
    elif selection == HIDDEN:
        connect_hidden_network()
        wifi_menu()
    elif selection == HOTSPOT:
        from network.hotspot import create_hotspot
        create_hotspot()
        wifi_menu()
    elif selection == STOP_HOTSPOT:
        from network.hotspot import stop_hotspot
        stop_hotspot()
        wifi_menu()
    elif selection == SAVED:
        saved_networks_menu()
    elif selection == POWERSAVE:
        toggle_power_save()
        wifi_menu()
    elif selection == RESCAN:
        invalidate("networks")
        invalidate("active_ssid")
        notify(title=NOTIFY_TITLE, message="Started scanning in background...", expire_time=4000)
        wifi_menu()
    elif selection == "OPEN_PORTAL":
        import subprocess
        for url in ("http://detectportal.firefox.com/canonical.html",
                    "http://captive.apple.com",
                    "http://www.msftconnecttest.com"):
            subprocess.Popen(["xdg-open", url])
        wifi_menu()
    elif selection in networks and selection != "~scanning~":
        show_network_actions(networks[selection])
