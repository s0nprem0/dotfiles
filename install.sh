#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────
# Arch Linux / WSL dotfiles installer
# Installs packages, deploys symlinks, sets up
# shell, services, and builds quickshell helpers.
# Pass --wsl to skip compositor/hardware packages.
#
# Usage:  ./install.sh [--wsl]
# ──────────────────────────────────────────────

DOTFILES="${DOTFILES:-$HOME/dotfiles}"
# Set REPO to your fork if cloning from a different location
REPO="${REPO:-https://github.com/jllyn/dotfiles}"

WSL_MODE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --wsl) WSL_MODE=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── XDG base directories ──
if [[ -z "${XDG_CONFIG_HOME:-}" ]]; then
  export XDG_CONFIG_HOME="$HOME/.config"
fi

# ── Sanity checks ──
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  echo "This script should NOT be run as root. Use a regular user with sudo."
  exit 1
fi

if ! command -v sudo &>/dev/null; then
  echo "sudo is required. Install it first:"
  echo "  pacman -S sudo"
  exit 1
fi

# Quick network check
if ! curl -s --max-time 5 https://archlinux.org &>/dev/null; then
  echo "No network connectivity. Check your connection and try again."
  exit 1
fi

if [[ ! -d "$DOTFILES" ]]; then
  echo "Cloning dotfiles into $DOTFILES ..."
  git clone "$REPO" "$DOTFILES"
fi

# Ensure .config directory exists before deploy
mkdir -p "$XDG_CONFIG_HOME"

# ──────────────────────────────────────────────
# Package lists
# ──────────────────────────────────────────────

# Official repositories
PACMAN_PKGS=(
  # Hyprland ecosystem
  hyprland hyprlock hypridle hyprpolkitagent
  # Wallpaper
  hyprpaper
  # Shell & terminal
  kitty zsh neovim
  # Audio
  pipewire wireplumber pipewire-pulse playerctl easyeffects pavucontrol
  # Bluetooth
  bluez bluez-utils blueman
  # Network
  networkmanager nm-connection-editor iw iwd
  # Screenshot, OCR, clipboard
  grim slurp tesseract tesseract-data-eng wl-clipboard
  # Backlight & power
  brightnessctl power-profiles-daemon upower thermald
  # File management
  udisks2 ranger thunar
  gvfs gvfs-mtp
  # Utilities
  fzf fd bat zoxide eza keychain jq socat powertop wlogout libnotify xdg-desktop-portal-hyprland
  # Development
  base-devel git rustup
  # Qt / GTK theming
  gtk3 gtk4 qt5ct qt6ct
  # Fonts
  ttf-font-awesome ttf-jetbrains-mono-nerd ttf-gohu-nerd noto-fonts
  # Auth / session
  gnome-keyring polkit-kde-agent
  rofi
  # QML shell
  quickshell
  # Clipboard manager
  cliphist
)

# AUR packages (installed via yay / paru)
AUR_PKGS=(
  uwsm                # Universal Wayland Session Manager
  matugen-bin         # Material You colour generator
  cloudflare-warp-bin # WARP VPN (optional, for network popup)
  udiskie             # Disk automounter with MTP support
  hyprland-preview-share-picker # GTK4 screen/window share picker
)

if $WSL_MODE; then
  WSL_SKIP_PACMAN=(
    hyprland hyprlock hypridle hyprpolkitagent
    hyprpaper
    pipewire wireplumber pipewire-pulse easyeffects pavucontrol
    bluez bluez-utils blueman
    networkmanager iw iwd
    grim slurp wl-clipboard
    brightnessctl power-profiles-daemon thermald
    udisks2 gvfs-mtp
    powertop wlogout
    xdg-desktop-portal-hyprland
    polkit-kde-agent
    rofi
    quickshell
    cliphist
  )
  WSL_SKIP_AUR=(
    uwsm
    udiskie
    hyprland-preview-share-picker
  )
  remove_items PACMAN_PKGS "${WSL_SKIP_PACMAN[@]}"
  remove_items AUR_PKGS "${WSL_SKIP_AUR[@]}"
  info "WSL mode: filtered out compositor/hardware packages"
fi

# ──────────────────────────────────────────────
# Helper functions
# ──────────────────────────────────────────────

# Use C locale for predictable command output
export LC_ALL=C

info() { printf "\033[1;34m==>\033[0m %s\n" "$*"; }
ok() { printf "\033[1;32m  ✓\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m  !\033[0m %s\n" "$*"; }
err() { printf "\033[1;31m  ✗\033[0m %s\n" "$*"; }

remove_items() {
  local -n arr=$1
  shift
  local skip=("$@")
  local result=()
  for item in "${arr[@]}"; do
    local found=false
    for s in "${skip[@]}"; do
      if [[ "$item" == "$s" ]]; then
        found=true
        break
      fi
    done
    $found || result+=("$item")
  done
  arr=("${result[@]}")
}

install_pacman() {
  sudo pacman -S --needed --noconfirm "$@"
}

install_aur_helper() {
  local helper="$1"
  if command -v "$helper" &>/dev/null; then
    return 0
  fi
  info "Installing $helper from AUR ..."
  local tmpdir
  tmpdir="$(mktemp -d)"
  git clone "https://aur.archlinux.org/$helper.git" "$tmpdir/$helper"
  (cd "$tmpdir/$helper" && makepkg -si --noconfirm)
  rm -rf "$tmpdir"
}

# ──────────────────────────────────────────────
# 1. Bootstrap: pacman keyring + base-devel
# ──────────────────────────────────────────────
info "Initialising pacman keyring (safe to re-run) ..."
sudo pacman-key --init 2>/dev/null || true
sudo pacman-key --populate archlinux 2>/dev/null || true

info "Updating package databases and system ..."
sudo pacman -Syu --noconfirm

info "Ensuring base-devel and git are installed ..."
sudo pacman -S --needed --noconfirm base-devel git

# ──────────────────────────────────────────────
# 2. Install official packages
# ──────────────────────────────────────────────
info "Installing official packages ..."
install_pacman "${PACMAN_PKGS[@]}"
ok "Official packages installed"

# ──────────────────────────────────────────────
# 3. AUR helper (user chooses)
# ──────────────────────────────────────────────
AUR_HELPER=""
if command -v yay &>/dev/null; then
  AUR_HELPER="yay"
elif command -v paru &>/dev/null; then
  AUR_HELPER="paru"
else
  echo ""
  echo "Which AUR helper would you like to use?"
  select choice in "paru (recommended)" "yay"; do
    case "$REPLY" in
    1)
      AUR_HELPER="paru"
      install_aur_helper "paru"
      break
      ;;
    2)
      AUR_HELPER="yay"
      install_aur_helper "yay"
      break
      ;;
    *) echo "Invalid choice. Enter 1 or 2." ;;
    esac
  done
fi

# ──────────────────────────────────────────────
# 4. Install AUR packages
# ──────────────────────────────────────────────
info "Installing AUR packages ..."
if [[ -z "${AUR_HELPER:-}" ]]; then
  warn "No AUR helper available; skipping AUR packages."
  warn "Install manually: ${AUR_PKGS[*]}"
else
  "${AUR_HELPER}" -S --needed --noconfirm "${AUR_PKGS[@]}"
fi
ok "AUR packages installed"

# ──────────────────────────────────────────────
# 5. Rust toolchain
# ──────────────────────────────────────────────
if ! command -v cargo &>/dev/null; then
  if ! command -v rustup &>/dev/null; then
    info "Installing rustup ..."
    sudo pacman -S --needed --noconfirm rustup
  fi
  info "Installing Rust toolchain ..."
  rustup install stable
  rustup default stable
fi
ok "Rust toolchain ready"

# ──────────────────────────────────────────────
# 6. Deploy dotfiles (symlinks)
# ──────────────────────────────────────────────
if [[ -f "$DOTFILES/deploy.sh" ]]; then
  info "Deploying dotfiles ..."
  "$DOTFILES/deploy.sh"
  ok "Dotfiles deployed"
else
  warn "deploy.sh not found; skipping dotfile deployment"
fi

# ── Set ZDOTDIR now that zsh config exists ──
if [[ -d "$XDG_CONFIG_HOME/zsh" ]]; then
  export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
fi

# ──────────────────────────────────────────────
# 7. Build quickshell helpers
# ──────────────────────────────────────────────
if ! $WSL_MODE && [[ -f "$DOTFILES/primo/Makefile" ]]; then
  info "Building quickshell Rust helpers ..."
  make -C "$DOTFILES/primo" all || warn "quickshell helpers build failed"
  ok "quickshell helpers built"
fi

# ──────────────────────────────────────────────
# 8. Deploy system-wide configs (etc/)
# ──────────────────────────────────────────────
if ! $WSL_MODE; then
  info "Deploying system configs from etc/ ..."
  if [[ -d "$DOTFILES/etc" ]]; then
    while IFS= read -r -d '' f; do
      rel="${f#"$DOTFILES/etc/"}"
      target="/etc/$rel"
      target_dir="$(dirname "$target")"
      sudo mkdir -p "$target_dir"
      sudo cp "$f" "$target"
      ok "$target"
    done < <(find "$DOTFILES/etc" -type f -print0)
  fi
fi

# ──────────────────────────────────────────────
# 9. Systemd services
# ──────────────────────────────────────────────
if ! $WSL_MODE; then
  info "Enabling systemd services ..."

  sudo systemctl enable --now NetworkManager.service 2>/dev/null && ok "NetworkManager" || warn "NetworkManager"
  sudo systemctl enable --now iwd.service 2>/dev/null && ok "iwd" || warn "iwd"
  sudo systemctl enable --now bluetooth.service 2>/dev/null && ok "bluetooth" || warn "bluetooth"
  sudo systemctl enable --now power-profiles-daemon 2>/dev/null && ok "power-profiles-daemon" || warn "power-profiles-daemon"
  sudo systemctl enable --now thermald 2>/dev/null && ok "thermald" || warn "thermald"
  sudo systemctl enable powertop.service 2>/dev/null && ok "powertop" || warn "powertop"

  systemctl --user daemon-reload 2>/dev/null
  systemctl --user enable --now pipewire.service 2>/dev/null && ok "pipewire (user)" || warn "pipewire"
  systemctl --user enable --now pipewire-pulse.service 2>/dev/null && ok "pipewire-pulse (user)" || warn "pipewire-pulse"
  systemctl --user enable --now wireplumber.service 2>/dev/null && ok "wireplumber (user)" || warn "wireplumber"
  systemctl --user enable --now gnome-keyring-daemon.service 2>/dev/null && ok "gnome-keyring (user)" || warn "gnome-keyring"
fi

# ──────────────────────────────────────────────
# 10. Clean up pacman cache
# ──────────────────────────────────────────────
info "Cleaning pacman cache ..."
sudo pacman -Sc --noconfirm 2>/dev/null && ok "Cache cleaned" || true

# ──────────────────────────────────────────────
# 11. Set default shell to zsh
# ──────────────────────────────────────────────
if [[ "$SHELL" != "$(command -v zsh)" ]]; then
  info "Setting zsh as default shell ..."
  if chsh -s "$(command -v zsh)" 2>/dev/null; then
    ok "Default shell changed to zsh (log out & back in to apply)"
  else
    warn "Could not change shell. Run manually: chsh -s $(command -v zsh)"
  fi
fi

# ──────────────────────────────────────────────
# Done
# ──────────────────────────────────────────────
echo ""

if $WSL_MODE; then
  echo "────────────────────────────────────────"
  echo "  All set!"
  echo ""
  echo "  Restart your terminal or run:"
  echo "    zsh"
  echo "────────────────────────────────────────"
else
  echo "────────────────────────────────────────"
  echo "  All set!"
  echo ""
  echo "  Log out and back in (or restart) to:"
  echo "    - Start a Hyprland session via uwsm"
  echo "    - Use zsh as your default shell"
  echo ""
  echo "  After logging in:"
  echo "    matugen image ~/wallpaper.jpg"
  echo "    quickshell --reload"
  echo "────────────────────────────────────────"
fi
