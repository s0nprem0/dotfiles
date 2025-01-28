import subprocess
import time
from typing import Optional
from dataclasses import dataclass
import os
import getpass
import json
import signal

from network import nm_dbus

# Temp files for async wifi scan
WIFI_SCAN_CACHE = f"/tmp/rofi_wifi_scan_{getpass.getuser()}.json"
WIFI_SCAN_PID = f"/tmp/rofi_wifi_scan_{getpass.getuser()}.pid"

import utils

# Re-export utils names that other modules import from common
notify = utils.notify
back_icon = utils.back_icon
BACK = utils.BACK
CONFIG_DIR = utils.CONFIG_DIR


def chk_nmcli(result, fail_msg: str) -> bool:
    """Check nmcli_run result; show error menu & return False on failure."""
    if isinstance(result, dict) and not result.get("ok"):
        errd = result.get("stderr") or result.get("stdout") or result.get("message", "")
        error_menu(fail_msg, errd)
        return False
    if not isinstance(result, dict):
        error_menu(fail_msg, "unexpected result type")
        return False
    return True


def chk_sudo(result, fail_msg: str) -> bool:
    """Check sudo_run result; show error menu & return False on failure."""
    if not result.get("ok"):
        error_menu(fail_msg, result.get("stderr", ""))
        return False
    return True

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
    band: str = ""

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
              urgent_rows: list[int] | None = None,
              return_raw: bool = False) -> str | tuple[str, str]:
    return utils.rofi_menu(options, prompt, ROFI_THEME, selected_row,
                           active_rows=active_rows, urgent_rows=urgent_rows,
                           return_raw=return_raw)


def rofi_custom_kb(raw: str) -> int:
    return utils.rofi_custom_kb(raw)


def error_menu(message: str, details: str = "") -> None:
    opts = [f"󰀨  {message}\0nonselectable\x1ftrue"]
    if details:
        opts.append(f"  {details[:160]}\0nonselectable\x1ftrue")
    opts.append(f"{utils.back_icon}  Back")
    rofi_menu(opts, prompt="󰀨  Error", selected_row=len(opts) - 1)


def confirm_menu(message: str) -> bool:
    return utils.confirm_menu(message, ROFI_THEME)


def rofi_input(prompt: str, default: str = "") -> str:
    return utils.rofi_input(prompt, default)


def rofi_password(prompt: str) -> str:
    return utils.rofi_password(prompt)

# ─── nmcli ──────────────────────────────────────────────────────────────────

def nmcli_run(args: list[str], *, error_title=None, error_notify=True,
               timeout=15, want_result=False) -> str | dict | None:
    return utils.nmcli_run(
        args,
        error_title=(error_title or NOTIFY_TITLE),
        error_notify=error_notify,
        timeout=timeout,
        want_result=want_result,
    )


# ─── Network State Queries ─────────────────────────────────────────────────

def is_wifi_enabled() -> bool:
    return nm_dbus.wifi_enabled()


def get_saved_networks() -> list[str]:
    return nm_dbus.saved_wifi_list()


def get_active_wifi() -> Optional[str]:
    return nm_dbus.get_active_wifi()


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
    # Auto-reap child to avoid zombie processes
    signal.signal(signal.SIGCHLD, signal.SIG_IGN)
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

def freq_to_band(freq: int) -> str:
    if 2412 <= freq <= 2484:
        return "2.4"
    if 5170 <= freq <= 5825:
        return "5"
    return ""


def list_wifi_networks(no_rescan: bool = True) -> dict[str, WifiNetwork]:
    # Trigger async scan via D-Bus if requested
    if not no_rescan:
        triggered = nm_dbus.trigger_scan()
        if not triggered and os.path.exists(WIFI_SCAN_CACHE):
            start_wifi_bg_scan()
    # Try D-Bus path (fast — reads NM internal AP cache directly)
    raw = nm_dbus.list_wifi(no_rescan=True)
    if raw:
        networks: dict[str, WifiNetwork] = {}
        for ssid, info in raw.items():
            networks[ssid] = WifiNetwork(
                ssid=ssid, security=info.get("security"),
                signal=info.get("signal", 0),
                saved=info.get("saved", False),
                visible=info.get("visible", True),
                band=freq_to_band(info.get("frequency", 0)),
            )
        return networks
    # Fallback: try the file cache
    saved = get_saved_networks()
    if os.path.exists(WIFI_SCAN_CACHE):
        try:
            with open(WIFI_SCAN_CACHE) as inf:
                js = json.load(inf)
            networks = {}
            for row in js:
                ssid = row.get("ssid")
                if not ssid: continue
                networks[ssid] = WifiNetwork(
                    ssid=ssid, security=row.get("security"), signal=row.get("signal", 0),
                    saved=ssid in saved, visible=True, band="",
                )
            return networks
        except Exception:
            pass
    if os.path.exists(WIFI_SCAN_PID):
        return {"~scanning~": WifiNetwork(
            ssid="Scanning...", security=None, signal=0, saved=False, visible=True, band="",
        )}
    return {}


def get_connection_prop(ssid: str, prop: str) -> str:
    return nm_dbus.get_connection_prop(ssid, prop)


def get_power_save(iface: str | None = None) -> Optional[bool]:
    if iface is None:
        iface = nm_dbus.get_wifi_iface()
    if not iface:
        return None
    try:
        out = subprocess.run(["iw", "dev", iface, "get", "power_save"],
                             capture_output=True, text=True, timeout=5).stdout.strip()
        return "on" in out.lower()
    except Exception:
        return None


def check_connectivity() -> str:
    return nm_dbus.get_connectivity()


PUBLIC_IP_CACHE = f"/tmp/rofi_public_ip_{getpass.getuser()}.txt"


def get_public_ip() -> Optional[str]:
    # Try file cache first (60s TTL)
    try:
        mtime = os.path.getmtime(PUBLIC_IP_CACHE)
        if time.time() - mtime < 60:
            with open(PUBLIC_IP_CACHE) as f:
                val = f.read().strip()
                if val:
                    return val
    except Exception:
        pass
    # Fetch in parallel with short timeout
    import urllib.request
    import concurrent.futures
    v4 = v6 = None
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as ex:
        f4 = ex.submit(lambda: urllib.request.urlopen("https://api.ipify.org", timeout=3).read().decode().strip())
        f6 = ex.submit(lambda: urllib.request.urlopen("https://api6.ipify.org", timeout=3).read().decode().strip())
        for f in (f4, f6):
            try:
                r = f.result(timeout=1.5)
                if f is f4:
                    v4 = r
                else:
                    v6 = r
            except Exception:
                pass
    if not v4 and not v6:
        return None
    parts = []
    if v4:
        parts.append(f"v4: {v4}")
    if v6:
        parts.append(f"v6: {v6}")
    val = "  ".join(parts)
    try:
        with open(PUBLIC_IP_CACHE, "w") as f:
            f.write(val)
    except Exception:
        pass
    return val


def get_vpn_list() -> list[str]:
    return nm_dbus.vpn_list()


def get_active_vpn() -> Optional[str]:
    return nm_dbus.get_active_vpn()
