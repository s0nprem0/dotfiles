# dotfiles

Personal dotfiles managed with a custom deploy script.

## What's included

| Directory       | Description                         |
|-----------------|-------------------------------------|
| `hypr/`         | Hyprland Lua config + scripts       |
| `quickshell/`   | Quickshell bar, popups, daemons (replaces waybar) |
| `rofi/`         | Rofi config (legacy, replaced by quickshell) |
| `waybar/`       | Waybar config (legacy, kept for reference) |
| `wlogout/`      | Power menu layout and styling       |
| `nvim/`         | Neovim (LazyVim-based)              |
| `kitty/`        | Kitty terminal emulator             |
| `tmux/`         | Tmux configuration                  |
| `zsh/`          | Zsh shell config                    |
| `matugen/`      | Material color generator            |
| `ranger/`       | Ranger file manager                 |
| `primo/`        | Rust source for quickshell helpers  |

## Usage

```sh
# Deploy all configs
./install.sh

# Deploy specific configs (run from repo root)
./deploy.sh  # Symlinks .config/* to ~/.config/
```

## WSL

The dotfiles include first-class WSL support (tested on Arch WSL2).

```sh
./install.sh --wsl
```

The `--wsl` flag:

- Skips all Hyprland/compositor, audio, Bluetooth, and hardware packages.
- Adds `wslu` for Windows interop (`wslview`, `wslpath`).
- Passes `--wsl` to `deploy.sh`, which skips Wayland-only configs
  (`hypr/`, `quickshell/`, `waybar/`, `wlogout/`, `uwsm/`, ...).
- Writes `/etc/wsl.conf` with `systemd=true` and `metadata` automount
  (fixes executable bits on `/mnt/c`), and offers to create a
  Windows-side `.wslconfig` (mirrored networking + DNS tunneling).

Shell behaviour under WSL:

- Windows `/mnt/*` entries are stripped from `PATH` so Windows executables
  never shadow Linux tools (interop still works via explicit `.exe` paths).
- `pbcopy`/`pbpaste`/tmux yank/nvim clipboard route through `clip.exe`.
- Interop aliases: `explorer`, `start`, `winpath`, `cdwin`, `open`.

After changing `/etc/wsl.conf` or `.wslconfig`, restart WSL from PowerShell:

```powershell
wsl --shutdown
```

systemd is required for `systemctl`, `docker-toggle`, and the SSH agent.
