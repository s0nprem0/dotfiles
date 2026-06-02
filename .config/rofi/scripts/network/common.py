import subprocess
from typing import Optional
from dataclasses import dataclass
import os
import getpass
import json

# Temp files for async wifi scan
WIFI_SCAN_CACHE = f"/tmp/rofi_wifi_scan_{getpass.getuser()}.json"
WIFI_SCAN_PID = f"/tmp/rofi_wifi_scan_{getpass.getuser()}.pid"

import utils

# Re-export utils names that other modules import from common
notify = utils.notify
back_icon = utils.back_icon
BACK = utils.BACK
CONFIG_DIR = utils.CONFIG_DIR

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
ROFI_THEME = str(utils.CONFIG_DIR / "rofi" / "wifi.rasi")

TOGGLE_WIFI = "TOGGLE_WIFI"
CONNECT = "Connect"
FORGET = "Forget"
DISCONNECT = "Disconnect"
HIDDEN = "HIDDEN"
RESCAN = "Rescan"
HOTSPOT = "HOTSPOT"
STOP_HOTSPOT = "STOP_HOTSPOT"
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

def rofi_menu(options: list[str], prompt: str, selected_row: int = 0,
              active_rows: list[int] | None = None,
              urgent_rows: list[int] | None = None) -> str:
    return utils.rofi_menu(options, prompt, ROFI_THEME, selected_row,
                           active_rows=active_rows, urgent_rows=urgent_rows)


def error_menu(message: str, details: str = "") -> None:
    opts = [f"Error: {message}"]
    if details:
        opts.append(details[:100])
    opts.append(f"{utils.back_icon}  Back")
    rofi_menu(opts, prompt=f"{wifi_enable}  Error", selected_row=1)


def confirm_menu(message: str) -> bool:
    return utils.confirm_menu(message, ROFI_THEME)


def rofi_input(prompt: str, default: str = "") -> str:
    return utils.rofi_input(prompt, default)


def rofi_password(prompt: str) -> str:
    return utils.rofi_password(prompt)

# ─── nmcli ──────────────────────────────────────────────────────────────────

def nmcli_run(args: list[str], *, error_title=None, error_notify=True,
               timeout=15, want_result=False) -> str | dict | None:
    return utils.run_cmd_safe(
        ["nmcli"] + args,
        error_title=(error_title or NOTIFY_TITLE),
        error_notify=error_notify,
        timeout=timeout,
        want_result=want_result,
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


def start_wifi_bg_scan():
    """Start nmcli wifi list scan in background, caching results on completion."""
    # Already running?
    if os.path.exists(WIFI_SCAN_PID):
        try:
            with open(WIFI_SCAN_PID, "r") as pidf:
                pid = int(pidf.read())
            os.kill(pid, 0)
            return
        except Exception:
            os.remove(WIFI_SCAN_PID)
    pid = os.fork()
    if pid == 0:
        # Child process: perform scan
        with open(WIFI_SCAN_PID, "w") as pidf:
            pidf.write(str(os.getpid()))
        try:
            raw = subprocess.check_output([
                "nmcli", "-t", "-f", "SECURITY,SSID,SIGNAL", "device", "wifi", "list", "--rescan", "yes"
            ], text=True, timeout=30)
            networks = []
            for line in raw.splitlines():
                parts = line.split(":")
                if len(parts) < 3: continue
                sec = parts[0]
                signal = int(parts[-1]) if parts[-1].isdigit() else 0
                ssid = ":".join(parts[1:-1])
                if ssid:
                    networks.append({"ssid": ssid, "security": sec, "signal": signal})
            with open(WIFI_SCAN_CACHE, "w") as outf:
                json.dump(networks, outf)
        except Exception:
            pass
        finally:
            if os.path.exists(WIFI_SCAN_PID):
                os.remove(WIFI_SCAN_PID)
        os._exit(0)

def list_wifi_networks(no_rescan: bool = True) -> dict[str, WifiNetwork]:
    saved_networks = get_saved_networks()
    # Asynchronous scan/caching logic
    if not no_rescan:
        start_wifi_bg_scan()
    # Try cache first (fast path, avoids race with just-finished scan)
    if os.path.exists(WIFI_SCAN_CACHE):
        try:
            with open(WIFI_SCAN_CACHE) as inf:
                js = json.load(inf)
            networks: dict[str, WifiNetwork] = {}
            for row in js:
                ssid = row.get("ssid")
                if not ssid: continue
                networks[ssid] = WifiNetwork(
                    ssid=ssid, security=row.get("security"), signal=row.get("signal", 0),
                    saved=ssid in saved_networks, visible=True
                )
            return networks
        except Exception:
            pass
    # No cache yet — see if scan is still in progress
    if os.path.exists(WIFI_SCAN_PID):
        return {"~scanning~": WifiNetwork(
            ssid="Scanning...", security=None, signal=0, saved=False, visible=True
        )}
    # Fallback: blocking call as last resort
    cmd = ["-t", "-f", "SECURITY,SSID,SIGNAL", "device", "wifi", "list", "--rescan", "no"]
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
    v4 = v6 = None
    try:
        v4 = urllib.request.urlopen("https://api.ipify.org", timeout=3).read().decode().strip()
    except Exception:
        pass
    try:
        v6 = urllib.request.urlopen("https://api6.ipify.org", timeout=3).read().decode().strip()
    except Exception:
        pass
    if not v4 and not v6:
        return None
    parts = []
    if v4:
        parts.append(f"v4: {v4}")
    if v6:
        parts.append(f"v6: {v6}")
    return "  ".join(parts)


def get_vpn_list() -> list[str]:
    out = nmcli_run(["-t", "-f", "NAME,TYPE", "connection", "show"])
    if out is None:
        return []
    return [line.split(":", 1)[0] for line in out.splitlines() if line.endswith(":vpn")]


def get_active_vpn() -> Optional[str]:
    out = nmcli_run(["-t", "-f", "NAME,TYPE", "connection", "show", "--active"])
    if out is None:
        return None
    for line in out.splitlines():
        name, typ = line.split(":", 1)
        if typ == "vpn":
            return name
    return None
