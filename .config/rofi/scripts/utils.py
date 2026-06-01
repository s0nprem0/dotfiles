#!/usr/bin/env python3

import os
import subprocess
from pathlib import Path

back_icon = "󰁍"
BACK = "Back"
CONFIG_DIR = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))


def notify(
    title: str = "",
    message: str = "",
    expire_time: int = 3_000,
    urgency: str = "normal",
) -> None:
    subprocess.run(
        [
            "notify-send",
            "-t",
            str(expire_time),
            "-u",
            urgency,
            title,
            message,
        ],
        check=False
    )


def run_cmd_safe(cmd: list[str], *, error_title: str | None = None, error_notify: bool = True, timeout: int = 15, want_result: bool = False) -> str | dict | None:
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, check=False, timeout=timeout)
        if res.returncode != 0:
            emsg = res.stderr or res.stdout or f"exit code {res.returncode}"
            if error_notify and error_title:
                notify(title=error_title, message=emsg, urgency="critical")
            if want_result:
                return {"ok": False, "stdout": res.stdout or None, "stderr": res.stderr or None, "returncode": res.returncode, "message": emsg}
            return None
        if want_result:
            return {"ok": True, "stdout": res.stdout.strip(), "returncode": 0}
        return res.stdout.strip()
    except subprocess.TimeoutExpired as e:
        msg = f"Command timed out after {timeout}s"
        if error_notify and error_title:
            notify(title=error_title, message=msg, urgency="critical")
        if want_result:
            return {"ok": False, "stdout": None, "stderr": str(e), "message": msg, "timeout": True}
        return None
    except Exception as e:
        if error_notify and error_title:
            notify(title=error_title, message=str(e), urgency="critical")
        if want_result:
            return {"ok": False, "stdout": None, "stderr": str(e), "message": str(e), "exception": True}
        return None


def rofi_menu(options: list[str], prompt: str, theme: str, selected_row: int = 0) -> str:
    result = subprocess.run(
        ["rofi", "-dmenu", "-i", "-p", prompt, "-theme", theme,
         "-selected-row", str(selected_row)],
        input="\n".join(options),
        text=True, capture_output=True,
    ).stdout.strip()
    return result


def confirm_menu(message: str, theme: str) -> bool:
    opts = ["  Yes", "  No"]
    chosen = rofi_menu(opts, prompt=message, theme=theme, selected_row=1)
    return bool(chosen and "Yes" in chosen)


def rofi_input(prompt: str, default: str = "") -> str:
    return subprocess.run(
        ["rofi", "-dmenu", "-p", prompt, "-theme", str(CONFIG_DIR / "rofi" / "password.rasi")],
        input=default, text=True, capture_output=True,
    ).stdout.strip()


def rofi_password(prompt: str) -> str:
    return subprocess.run(
        ["rofi", "-dmenu", "-password", "-p", prompt, "-theme", str(CONFIG_DIR / "rofi" / "password.rasi")],
        capture_output=True, text=True,
    ).stdout.strip()
