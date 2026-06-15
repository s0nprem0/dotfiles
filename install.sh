#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────
# Arch Linux dotfiles installer
# Installs packages, deploys symlinks, sets up
# shell, services, and builds quickshell helpers.
#
# Usage:  ./install.sh
# ──────────────────────────────────────────────

DOTFILES="${DOTFILES:-$HOME/dotfiles}"
REPO="https://github.com/s0nprem0/dotfiles"

# ── XDG base directories ──
if [[ -z "${XDG_CONFIG_HOME:-}" ]]; then
  export XDG_CONFIG_HOME="$HOME/.config"
fi

# ── Sanity checks ──
if [[ ! -d "$DOTFILES" ]]; then
  echo "Cloning dotfiles into $DOTFILES ..."
  git clone "$REPO" "$DOTFILES"
fi

if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  echo "This script should NOT be run as root. Use a regular user with sudo."
  exit 1
fi

if ! command -v sudo &>/dev/null; then
  echo "sudo is required. Install it first:"
  echo "  pacman -S sudo"
  exit 1
fi

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
  networkmanager nm-connection-editor iw
  # Screenshot, OCR, clipboard
  grim slurp tesseract tesseract-data-eng wl-clipboard
  # Backlight & power
  brightnessctl power-profiles-daemon upower
  # File management
  udisks2 ranger thunar
  # Utilities
  fzf fd bat zoxide eza keychain jq socat wlogout
  # Development
  base-devel git rustup
  # Qt / GTK theming
  gtk3 gtk4 qt5ct qt6ct
  # Fonts
  ttf-font-awesome ttf-jetbrains-mono-nerd noto-fonts
  # Auth / session
  gnome-keyring polkit-kde-agent
  rofi
)

# AUR packages (installed via yay / paru)
AUR_PKGS=(
  uwsm           # Universal Wayland Session Manager
  quickshell-git # QML widget shell
  matugen-bin    # Material You colour generator
  cliphist       # Clipboard manager with history
)

# ──────────────────────────────────────────────
# Helper functions
# ──────────────────────────────────────────────

info() { printf "\033[1;34m==>\033[0m %s\n" "$*"; }
ok() { printf "\033[1;32m  ✓\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m  !\033[0m %s\n" "$*"; }
err() { printf "\033[1;31m  ✗\033[0m %s\n" "$*"; }

install_pacman() {
  sudo pacman -S --needed --noconfirm "$@" 2>&1 | grep -v "^::\|^ \(checking\|loading\|resolving\|looking\| Package\)"
}

install_aur_helper() {
  local helper="$1"
  if command -v "$helper" &>/dev/null; then
    return 0
  fi
  info "Installing $helper from AUR ..."
  sudo pacman -S --needed --noconfirm base-devel git
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

info "Updating system ..."
sudo pacman -Sy --noconfirm

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
"$AUR_HELPER" -S --needed --noconfirm "${AUR_PKGS[@]}" 2>&1 | grep -v "^::\|^\s"
ok "AUR packages installed"

# ──────────────────────────────────────────────
# 5. Rust toolchain
# ──────────────────────────────────────────────
if ! command -v cargo &>/dev/null; then
  info "Installing Rust toolchain ..."
  rustup default stable 2>/dev/null || {
    # rustup installed but no toolchain set
    rustup install stable
    rustup default stable
  }
fi
ok "Rust toolchain ready"

# ──────────────────────────────────────────────
# 6. Deploy dotfiles (symlinks)
# ──────────────────────────────────────────────
info "Deploying dotfiles ..."
"$DOTFILES/deploy.sh"
ok "Dotfiles deployed"

# ── Set ZDOTDIR now that zsh config exists ──
if [[ -d "$XDG_CONFIG_HOME/zsh" ]]; then
  export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
fi

# ──────────────────────────────────────────────
# 7. Build quickshell helpers
# ──────────────────────────────────────────────
if [[ -f "$DOTFILES/.config/quickshell/helpers_rs/Makefile" ]]; then
  info "Building quickshell Rust helpers ..."
  make -C "$DOTFILES/.config/quickshell/helpers_rs" all
  ok "quickshell helpers built"
fi

# ──────────────────────────────────────────────
# 8. Systemd services
# ──────────────────────────────────────────────
info "Enabling systemd services ..."

sudo systemctl enable --now bluetooth.service 2>/dev/null && ok "bluetooth" || warn "bluetooth"
sudo systemctl enable --now NetworkManager.service 2>/dev/null && ok "NetworkManager" || warn "NetworkManager"
sudo systemctl enable --now power-profiles-daemon 2>/dev/null && ok "power-profiles-daemon" || warn "power-profiles-daemon"

systemctl --user enable --now pipewire.service 2>/dev/null && ok "pipewire (user)" || warn "pipewire"
systemctl --user enable --now pipewire-pulse.service 2>/dev/null && ok "pipewire-pulse (user)" || warn "pipewire-pulse"
systemctl --user enable --now wireplumber.service 2>/dev/null && ok "wireplumber (user)" || warn "wireplumber"

systemctl --user enable --now gnome-keyring-daemon.service 2>/dev/null && ok "gnome-keyring (user)" || warn "gnome-keyring"

# ──────────────────────────────────────────────
# 9. Set default shell to zsh
# ──────────────────────────────────────────────
if [[ "$SHELL" != "$(which zsh)" ]]; then
  info "Setting zsh as default shell ..."
  chsh -s "$(which zsh)"
  ok "Default shell changed to zsh (log out & back in to apply)"
fi

# ──────────────────────────────────────────────
# Done
# ──────────────────────────────────────────────
echo ""
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
