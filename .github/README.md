# dotfiles

Personal dotfiles managed with GNU Stow.

## What's included

| Directory       | Description                         |
|-----------------|-------------------------------------|
| `hypr/`         | Hyprland Lua config + scripts       |
| `quickshell/`   | Quickshell bar, popups, daemons (replaces waybar) |
| `rofi/`         | Rofi app launcher, wifi, bluetooth  |
| `waybar/`       | Waybar status bar (legacy, replaced by quickshell) |
| `wlogout/`      | Power menu layout and styling       |
| `nvim/`         | Neovim (LazyVim-based)              |
| `kitty/`        | Kitty terminal emulator             |
| `tmux/`         | Tmux configuration                  |
| `zsh/`          | Zsh shell config                    |
| `gtk-3.0/`      | GTK3 theme/settings                 |
| `gtk-4.0/`      | GTK4 theme/settings                 |
| `matugen/`      | Material color generator            |
| `ranger/`       | Ranger file manager                 |
| `lazygit/`      | Lazygit UI config                   |
| `helpers_rs/`   | Rust source for quickshell helpers  |

## Usage

```sh
# Single config
stow -vt ~ nvim

# Multiple configs
stow -vt ~ {hypr,rofi,waybar,nvim,zsh,tmux,kitty}

# Everything
stow -vt ~ */
```
