import subprocess
from typing import Optional
from dataclasses import dataclass

from utils import notify, run_cmd_safe, back_icon, BACK, CONFIG_DIR
from utils import rofi_menu as _rofi_menu, confirm_menu as _confirm_menu, rofi_password as _rofi_password

# ─── Icons ──────────────────────────────────────────────────────────────────

shut_lock = ""
open_lock = ""
wifi_enable = "󰖩"
wifi_disable = "󰖪"
wifi_known = "󰆓"
connect_icon = "󱘖"
forget_icon = "󰩹"
new_icon = "󰐕"
disconnect_icon = "󰐥"
hidden_icon = "󰐗"
ethernet_icon = "󰈀"
vpn_icon = ""

# ─── Constants ──────────────────────────────────────────────────────────────

NOTIFY_TITLE = "Network Manager"
ROFI_THEME = str(CONFIG_DIR / "rofi" / "wifi.rasi")

TOGGLE_WIFI = "TOGGLE_WIFI"
CONNECT = "Connect"
FORGET = "Forget"
DISCONNECT = "Disconnect"
HIDDEN = "HIDDEN"
RESCAN = "Rescan"
HOTSPOT = "HOTSPOT"
SAVED = "SAVED"
POWERSAVE = "POWERSAVE"

NOTIFY_OK = dict(expire_time=3_000, urgency="low")
NOTIFY_BUSY = dict(expire_time=10_000)

# ─── Dataclass ──────────────────────────────────────────────────────────────

@dataclass(slots=True)
class WifiNetwork:
    ssid: str
    security: Optional[str]
    signal: int
    saved: bool
    visible: bool

# ─── Signal ─────────────────────────────────────────────────────────────────

def signal_bars(signal: int) -> str:
    if signal >= 80:
        return "󰤨"
    elif signal >= 60:
        return "󰤥"
    elif signal >= 40:
        return "󰤢"
    elif signal >= 20:
        return "󰤟"
    else:
        return "󰤯"

# ─── Rofi Wrappers ──────────────────────────────────────────────────────────

def rofi_menu(options: list[str], prompt: str, selected_row: int = 0) -> str:
    return _rofi_menu(options, prompt, ROFI_THEME, selected_row)


def error_menu(message: str) -> None:
    opts = [f"Error: {message}", f"{back_icon}  Back"]
    rofi_menu(opts, prompt=f"{wifi_enable}  Error", selected_row=1)


def confirm_menu(message: str) -> bool:
    return _confirm_menu(message, ROFI_THEME)


def rofi_password(prompt: str) -> str:
    return _rofi_password(prompt)

# ─── nmcli ──────────────────────────────────────────────────────────────────

def nmcli_run(args: list[str], *, error_title=None, error_notify=True,
              timeout=15) -> str | None:
    return run_cmd_safe(
        ["nmcli"] + args,
        error_title=(error_title or NOTIFY_TITLE),
        error_notify=error_notify,
        timeout=timeout,
    )

# ─── Network State Queries ─────────────────────────────────────────────────

def is_wifi_enabled() -> bool:
    res = nmcli_run(["-f", "WIFI", "g"])
    if res is None:
        return False
    return "enabled" in res


def get_saved_networks() -> list[str]:
    res = nmcli_run(["-t", "-f", "NAME,TYPE", "connection", "show"])
    if res is None:
        return []
    return [c.split(":", 1)[0] for c in res.splitlines() if c.endswith("wireless")]


def get_active_wifi() -> Optional[str]:
    res = nmcli_run(["-t", "-f", "NAME,TYPE", "connection", "show", "--active"])
    if res is None:
        return None
    for line in res.splitlines():
        name, typ = line.split(":", 1)
        if typ == "wireless":
            return name
    return None


def list_wifi_networks(no_rescan: bool = True) -> dict[str, WifiNetwork]:
    saved_networks = get_saved_networks()
    cmd = ["-t", "-f", "SECURITY,SSID,SIGNAL", "device", "wifi", "list"]
    if no_rescan:
        cmd += ["--rescan", "no"]
    res = nmcli_run(cmd)
    if res is None:
        return {}
    networks: dict[str, WifiNetwork] = {}
    for line in res.splitlines():
        parts = line.split(":")
        if len(parts) < 3:
            continue
        security = parts[0]
        signal = int(parts[-1]) if parts[-1].isdigit() else 0
        ssid = ":".join(parts[1:-1])
        if ssid:
            networks[ssid] = WifiNetwork(
                ssid=ssid, security=security, signal=signal,
                saved=ssid in saved_networks, visible=True,
            )
    return networks


def get_connection_prop(ssid: str, prop: str) -> str:
    res = nmcli_run(["connection", "show", "id", ssid])
    if res is None:
        return ""
    for line in res.splitlines():
        if line.startswith(f"{prop}:"):
            return line.split(":", 1)[1].strip()
    return ""


def get_power_save() -> Optional[bool]:
    res = nmcli_run(["-t", "-f", "DEVICE,TYPE", "device"])
    if res is None:
        return None
    iface = None
    for line in res.splitlines():
        dev, typ = line.split(":", 1)
        if typ == "wifi":
            iface = dev
            break
    if not iface:
        return None
    try:
        out = subprocess.run(["iw", "dev", iface, "get", "power_save"],
                             capture_output=True, text=True, timeout=5).stdout.strip()
        return "on" in out.lower()
    except Exception:
        return None


def check_connectivity() -> str:
    res = nmcli_run(["networking", "connectivity", "check"])
    if res is None:
        return "unknown"
    return res.strip()


def get_public_ip() -> Optional[str]:
    import urllib.request
    try:
        return urllib.request.urlopen("https://ifconfig.me", timeout=5).read().decode().strip()
    except Exception:
        return None


def get_vpn_list() -> list[str]:
    out = nmcli_run(["-t", "-f", "NAME,TYPE", "connection", "show"])
    if out is None:
        return []
    return [line.split(":")[0] for line in out.splitlines() if line.endswith(":vpn")]


def get_active_vpn() -> Optional[str]:
    out = nmcli_run(["-t", "-f", "NAME,TYPE", "connection", "show", "--active"])
    if out is None:
        return None
    for line in out.splitlines():
        name, typ = line.split(":", 1)
        if typ == "vpn":
            return name
    return None
