import subprocess
import sys

from utils import notify, run_cmd_safe, back_icon, CONFIG_DIR
from utils import rofi_menu as _rofi_menu, confirm_menu as _confirm_menu

bt_icon = ""
bt_disabled = ""
power_icon = ""
scan_icon = ""
pairable_icon = ""
discoverable_icon = ""
connect_icon = "󱘖"
disconnect_icon = "󰐥"
pair_icon = ""
remove_icon = "󰩹"
trust_icon = ""
untrust_icon = ""
info_icon = ""
audio_icon = ""
input_icon = ""
phone_icon = ""
rename_icon = ""

_scanned: bool = False
_previous_sink: str | None = None
NOTIFY_TITLE = f"{bt_icon}  Bluetooth Manager"
ROFI_THEME = str(CONFIG_DIR / "rofi" / "bluetooth.rasi")

_info_cache: dict[str, str] = {}


def _get_info(mac: str) -> str | None:
    """Cached bluetoothctl info for a device. Returns None on failure (retriable)."""
    if mac not in _info_cache:
        try:
            res = subprocess.run(
                ["bluetoothctl", "info", mac],
                capture_output=True, text=True, check=False, timeout=15
            )
            out = res.stdout.strip()
            if out:
                _info_cache[mac] = out
            else:
                return None
        except (subprocess.TimeoutExpired, subprocess.SubprocessError, FileNotFoundError):
            return None
    return _info_cache.get(mac)


def bluetoothctl(args: list[str], timeout: int = 15) -> str | None:
    """Run bluetoothctl. Returns None on error."""
    return run_cmd_safe(["bluetoothctl"] + args, error_title=NOTIFY_TITLE, timeout=timeout)


def rfkill(args: list[str]) -> str | None:
    """Run rfkill. Returns None on error."""
    return run_cmd_safe(["rfkill"] + args, error_title=NOTIFY_TITLE)


def rofi_menu(options: list[str], prompt: str, selected_row: int = 0) -> str:
    return _rofi_menu(options, prompt, ROFI_THEME, selected_row)


def error_menu(message: str, back_action) -> None:
    _rofi_menu([f"Error: {message}", f"{back_icon}  Back"], f"{bt_icon}  Error", ROFI_THEME, 1)
    back_action()


def power_on() -> bool:
    res = bluetoothctl(["show"])
    if res is None:
        return False
    return "Powered: yes" in res


def scan_on() -> bool:
    res = bluetoothctl(["show"])
    if res is None:
        return False
    return "Discovering: yes" in res


def pairable_on() -> bool:
    res = bluetoothctl(["show"])
    if res is None:
        return False
    return "Pairable: yes" in res


def discoverable_on() -> bool:
    res = bluetoothctl(["show"])
    if res is None:
        return False
    return "Discoverable: yes" in res


def device_connected(mac: str) -> bool:
    res = _get_info(mac)
    if res is None:
        return False
    return "Connected: yes" in res


def device_paired(mac: str) -> bool:
    res = _get_info(mac)
    if res is None:
        return False
    return "Paired: yes" in res


def device_trusted(mac: str) -> bool:
    res = _get_info(mac)
    if res is None:
        return False
    return "Trusted: yes" in res


def get_device_name(mac: str) -> str:
    info = _get_info(mac)
    if info is None:
        return mac
    n = None
    a = None
    uuid = None
    for line in info.splitlines():
        stripped = line.strip()
        if stripped.startswith("Name:"):
            n = stripped.split(":", 1)[1].strip()
        elif stripped.startswith("Alias:"):
            a = stripped.split(":", 1)[1].strip()
        elif stripped.startswith("UUID:") and uuid is None:
            uuid = stripped.split("(")[0].replace("UUID:", "").strip()
    name = n or a or ""
    if name and not name.startswith(mac.split(":")[0]):
        return name
    return f"{uuid} ({mac})" if uuid else mac


def get_device_type(mac: str) -> str:
    """Returns 'audio', 'input', 'phone', or 'generic' based on UUIDs/Icon/Class."""
    info = _get_info(mac)
    if info is None:
        return "generic"
    for line in info.splitlines():
        stripped = line.strip()
        if stripped.startswith("UUID:"):
            if any(x in stripped for x in ("0000110b", "00001108", "0000110e", "0000110a")):
                return "audio"
            if "00001124" in stripped:
                return "input"
            if any(x in stripped for x in ("0000111e", "0000111f")):
                return "phone"
        if stripped.startswith("Icon:"):
            icon = stripped.split(":", 1)[1].strip()
            if "audio" in icon or "headset" in icon:
                return "audio"
            if "input" in icon or "keyboard" in icon or "mouse" in icon:
                return "input"
            if "phone" in icon:
                return "phone"
        if stripped.startswith("Class:"):
            cls = stripped.split(":", 1)[1].strip()
            if "0x002404" in cls or "0x002004" in cls or "0x002408" in cls:
                return "audio"
    return "generic"


def get_battery(mac: str) -> str | None:
    """Returns battery percentage string if available."""
    info = _get_info(mac)
    if info is None:
        return None
    for line in info.splitlines():
        stripped = line.strip()
        if stripped.startswith("Battery Percentage:"):
            parts = stripped.split(":")
            if len(parts) >= 2:
                val = parts[1].strip()
                return val.replace("0x", "").strip()
    return None


def confirm_menu(prompt: str) -> bool:
    return _confirm_menu(prompt, ROFI_THEME)


def _get_bt_sink(mac: str) -> str | None:
    """Find the PulseAudio sink name for a BT device by MAC."""
    out = run_cmd_safe(["pactl", "list", "sinks", "short"], timeout=10)
    if out is None:
        return None
    bt_mac = mac.replace(":", "_")
    for line in out.splitlines():
        parts = line.strip().split("\t")
        if len(parts) >= 2 and bt_mac in parts[1] and "bluez" in parts[1].lower():
            return parts[1]
    return None


def _get_default_sink() -> str | None:
    out = run_cmd_safe(["pactl", "get-default-sink"], timeout=10)
    return out.strip() if out else None


def _set_default_sink(sink: str) -> bool:
    return run_cmd_safe(["pactl", "set-default-sink", sink], timeout=10) is not None


def switch_audio_sink(mac: str, connect: bool) -> None:
    """Switch audio output to/from a Bluetooth device."""
    global _previous_sink
    name = get_device_name(mac)
    if connect:
        bt_sink = _get_bt_sink(mac)
        if bt_sink is None:
            notify(title=NOTIFY_TITLE, message=f"No BT audio sink found for {name}")
            return
        current = _get_default_sink()
        if current and current != bt_sink:
            _previous_sink = current
        if _set_default_sink(bt_sink):
            notify(title=NOTIFY_TITLE, message=f"Audio switched to {name}")
        else:
            notify(title=NOTIFY_TITLE, message=f"Failed to switch audio to {name}")
    else:
        if _previous_sink and _set_default_sink(_previous_sink):
            notify(title=NOTIFY_TITLE, message=f"Audio switched back to default")
        _previous_sink = None


def rename_device(mac: str) -> None:
    name = get_device_name(mac)
    chosen = subprocess.run(
        ["rofi", "-dmenu", "-p", "New name", "-theme", str(CONFIG_DIR / "rofi" / "input.rasi")],
        input=name, text=True, capture_output=True
    ).stdout.strip()
    if not chosen or chosen == name:
        device_menu(mac)
        return
    r = bluetoothctl(["set-alias", mac, chosen])
    if r is None:
        error_menu(f"Failed to rename {name}", lambda: device_menu(mac))
        return
    _info_cache.pop(mac, None)
    notify(title=NOTIFY_TITLE, message=f"Renamed to {chosen}")
    device_menu(mac)


def get_paired_devices() -> list[tuple[str, str]]:
    """returns list of (mac, name) for all known devices. Returns [] on failure."""
    out = bluetoothctl(["devices"])
    if out is None:
        return []
    devices: list[tuple[str, str]] = []
    for line in out.splitlines():
        parts = line.split(" ", 2)
        if len(parts) == 3 and parts[0] == "Device":
            devices.append((parts[1], parts[2]))
    return devices


def toggle_power() -> None:
    if power_on():
        r = bluetoothctl(["power", "off"])
        if r is None:
            error_menu("Failed to power off bluetooth", main_menu)
            return
        notify(title=NOTIFY_TITLE, message="Power turned off")
    else:
        rlist = rfkill(["list", "bluetooth"])
        if rlist is not None and "blocked" in rlist:
            run = rfkill(["unblock", "bluetooth"])
            if run is None:
                error_menu("Failed to unblock bluetooth", main_menu)
                return
        r = bluetoothctl(["power", "on"])
        if r is None:
            error_menu("Failed to power on bluetooth", main_menu)
            return
        notify(title=NOTIFY_TITLE, message="Power turned on")
    _info_cache.clear()
    main_menu()


def toggle_scan() -> None:
    if scan_on():
        r = bluetoothctl(["scan", "off"])
        if r is None:
            notify(title=NOTIFY_TITLE, message="Scan already stopped")
        else:
            notify(title=NOTIFY_TITLE, message="Scan stopped")
        main_menu()
        return

    notify(title=NOTIFY_TITLE, message="Scanning for 10 seconds...")
    _info_cache.clear()
    r = bluetoothctl(["--timeout", "10", "scan", "on"], timeout=20)
    if r is None:
        error_menu("Failed to scan for devices", main_menu)
        return
    devices = get_paired_devices()
    for mac, _ in devices:
        _get_info(mac)
    if not devices:
        notify(title=NOTIFY_TITLE, message="No Bluetooth devices found")
    else:
        notify(title=NOTIFY_TITLE, message=f"Scan finished — {len(devices)} device(s) found")
    main_menu()


def toggle_pairable() -> None:
    if pairable_on():
        r = bluetoothctl(["pairable", "off"])
        if r is None:
            error_menu("Failed to set pairable off", main_menu)
            return
        notify(title=NOTIFY_TITLE, message="Pairable: off")
    else:
        r = bluetoothctl(["pairable", "on"])
        if r is None:
            error_menu("Failed to set pairable on", main_menu)
            return
        notify(title=NOTIFY_TITLE, message="Pairable: on")
    main_menu()


def toggle_discoverable() -> None:
    if discoverable_on():
        r = bluetoothctl(["discoverable", "off"])
        if r is None:
            error_menu("Failed to set discoverable off", main_menu)
            return
        notify(title=NOTIFY_TITLE, message="Discoverable: off")
    else:
        r = bluetoothctl(["discoverable", "on"])
        if r is None:
            error_menu("Failed to set discoverable on", main_menu)
            return
        notify(title=NOTIFY_TITLE, message="Discoverable: on")
    main_menu()


def toggle_connection(mac: str) -> None:
    name = get_device_name(mac)
    if device_connected(mac):
        if get_device_type(mac) == "audio":
            switch_audio_sink(mac, False)
        r = bluetoothctl(["disconnect", mac])
        if r is None:
            error_menu(f"Failed to disconnect from {name}", lambda: device_menu(mac))
            return
        notify(title=NOTIFY_TITLE, message=f"Disconnected from {name}")
    else:
        r = bluetoothctl(["connect", mac])
        if r is None:
            error_menu(f"Failed to connect to {name}", lambda: device_menu(mac))
            return
        notify(title=NOTIFY_TITLE, message=f"Connected to {name}")
        if get_device_type(mac) == "audio":
            switch_audio_sink(mac, True)
    device_menu(mac)


def toggle_pair(mac: str) -> None:
    name = get_device_name(mac)
    if device_paired(mac):
        if not confirm_menu(f"Remove {name}?"):
            device_menu(mac)
            return
        r = bluetoothctl(["remove", mac])
        if r is None:
            error_menu(f"Failed to remove {name}", lambda: device_menu(mac))
            return
        notify(title=NOTIFY_TITLE, message=f"Removed {name}")
    else:
        r = bluetoothctl(["pair", mac])
        if r is None:
            error_menu(f"Failed to pair with {name}", lambda: device_menu(mac))
            return
        notify(title=NOTIFY_TITLE, message=f"Paired with {name}")
    device_menu(mac)


def toggle_trust(mac: str) -> None:
    name = get_device_name(mac)
    if device_trusted(mac):
        r = bluetoothctl(["untrust", mac])
        if r is None:
            error_menu(f"Failed to untrust {name}", lambda: device_menu(mac))
            return
        notify(title=NOTIFY_TITLE, message=f"Untrusted {name}")
    else:
        r = bluetoothctl(["trust", mac])
        if r is None:
            error_menu(f"Failed to trust {name}", lambda: device_menu(mac))
            return
        notify(title=NOTIFY_TITLE, message=f"Trusted {name}")
    device_menu(mac)


def show_device_info_menu(mac: str, back_fn) -> None:
    info = bluetoothctl(["info", mac])
    if info is None:
        error_menu("Could not fetch device info", lambda: device_menu(mac))
        return
    keep_prefixes = ("Name:", "Alias:", "Device ", "Paired:", "Trusted:",
                     "Connected:", "UUID:", "ManufacturerData.Key:",
                     "Modalias:", "Battery Percentage:")
    lines = [line.strip() for line in info.splitlines() if line.strip()
             and any(line.strip().startswith(p) for p in keep_prefixes)]
    opts = list(dict.fromkeys(lines))
    battery = get_battery(mac)
    if battery:
        opts.insert(0, f"  Battery: {battery}%")
    opts.append(f"{back_icon}  Back")
    chosen = rofi_menu(opts, prompt=f"{info_icon} Device Info", selected_row=len(opts) - 1)
    if not chosen or chosen.endswith("Back"):
        back_fn(mac)


def device_menu(mac: str) -> None:
    name = get_device_name(mac)
    paired = device_paired(mac)
    connected = device_connected(mac)
    trusted = device_trusted(mac)

    options = []
    if connected:
        options.append(f"{disconnect_icon}  Disconnect")
    else:
        options.append(f"{connect_icon}  Connect")

    if paired:
        options.append(f"{remove_icon}  Remove")
    else:
        options.append(f"{pair_icon}  Pair")

    if trusted:
        options.append(f"{untrust_icon}  Untrust")
    else:
        options.append(f"{trust_icon}  Trust")

    options.append(f"{info_icon}  Info")
    options.append(f"{rename_icon}  Rename")
    options.append(f"{scan_icon}  Rescan")
    options.append(f"{back_icon}  Back")

    chosen = rofi_menu(options, f"  {bt_icon}  {name}")
    if not chosen:
        return

    if "Disconnect" in chosen:
        toggle_connection(mac)
    elif "Connect" in chosen:
        toggle_connection(mac)
    elif "Remove" in chosen:
        toggle_pair(mac)
    elif "Pair" in chosen:
        toggle_pair(mac)
    elif "Untrust" in chosen:
        toggle_trust(mac)
    elif "Trust" in chosen:
        toggle_trust(mac)
    elif "Info" in chosen:
        show_device_info_menu(mac, device_menu)
    elif "Rename" in chosen:
        rename_device(mac)
    elif "Rescan" in chosen:
        toggle_scan()
    elif "Back" in chosen:
        main_menu()


def main_menu() -> None:
    global _scanned
    pwr = power_on()

    options: list[str] = []

    if pwr:
        devices = get_paired_devices()
        type_icon = {"audio": audio_icon, "input": input_icon, "phone": phone_icon, "generic": bt_icon}
        for mac, _ in devices:
            if device_connected(mac):
                icon = connect_icon
            else:
                icon = type_icon.get(get_device_type(mac), bt_icon)
            battery = get_battery(mac)
            name = get_device_name(mac)
            label = f"{icon}  {name}" if not battery else f"{icon}  {name}  ({battery}%)"
            options.append(label)

        if not devices and not _scanned:
            _scanned = True
            _info_cache.clear()
            notify(title=NOTIFY_TITLE, message="Scanning for 10 seconds...")
            bluetoothctl(["--timeout", "10", "scan", "on"], timeout=20)
            for dmac, _ in get_paired_devices():
                _get_info(dmac)
            main_menu()
            return

        options.append("──────────")
        options.append(f"{power_icon}  Power: on")
        options.append(f"{scan_icon}  Scan: {'on' if scan_on() else 'off'}")
        options.append(f"{pairable_icon}  Pairable: {'on' if pairable_on() else 'off'}")
        options.append(f"{discoverable_icon}  Discoverable: {'on' if discoverable_on() else 'off'}")
    else:
        options.append(f"{power_icon}  Power: off")

    options.append(f"{back_icon}  Exit")

    chosen = rofi_menu(options, f" {bt_icon}  Bluetooth")
    if not chosen:
        return

    if "Power: on" in chosen:
        toggle_power()
    elif "Power: off" in chosen:
        toggle_power()
    elif "Scan: on" in chosen or "Scan: off" in chosen:
        toggle_scan()
    elif "Pairable: on" in chosen or "Pairable: off" in chosen:
        toggle_pairable()
    elif "Discoverable: on" in chosen or "Discoverable: off" in chosen:
        toggle_discoverable()
    elif chosen == f"{back_icon}  Exit" or chosen == "──────────":
        return
    else:
        if chosen.startswith("Error:"):
            return
        for mac, _ in get_paired_devices():
            if get_device_name(mac) in chosen:
                device_menu(mac)
                return


def print_status() -> None:
    if power_on():
        connected_names: list[str] = []
        for mac, _ in get_paired_devices():
            if device_connected(mac):
                connected_names.append(get_device_name(mac))
        if connected_names:
            print(f"{bt_icon}  {', '.join(connected_names)}")
        else:
            print(bt_icon)
    else:
        print(bt_disabled)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--status":
        print_status()
    else:
        main_menu()
