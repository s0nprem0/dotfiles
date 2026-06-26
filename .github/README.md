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
