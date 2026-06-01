# dotfiles

Personal dotfiles managed with GNU Stow.

## What's included

| Directory       | Description                         |
|-----------------|-------------------------------------|
| `hypr/`         | Hyprland Lua config + scripts       |
| `rofi/`         | Rofi app launcher, wifi, bluetooth  |
| `waybar/`       | Waybar status bar                   |
| `wlogout/`      | Power menu layout and styling       |
| `nvim/`         | Neovim (LazyVim-based)              |
| `kitty/`        | Kitty terminal emulator             |
| `tmux/`         | Tmux configuration                  |
| `zsh/`          | Zsh shell config                    |
| `swaync/`       | Sway notification center            |
| `wofi/`         | Wofi launcher                       |
| `gtk-3.0/`      | GTK3 theme/settings                 |
| `gtk-4.0/`      | GTK4 theme/settings                 |
| `matugen/`      | Material color generator            |
| `ranger/`       | Ranger file manager                 |
| `lazygit/`      | Lazygit UI config                   |

## Usage

```sh
# Single config
stow -vt ~ nvim

# Multiple configs
stow -vt ~ {hypr,rofi,waybar,nvim,zsh,tmux,kitty}

# Everything
stow -vt ~ */
```
