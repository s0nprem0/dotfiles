#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────
# Arch Linux / WSL dotfiles installer
# Installs packages, deploys symlinks, sets up
# shell and services, and builds the primo Rust helpers.
# Pass --wsl to skip compositor/hardware packages
# and configure WSL (systemd, metadata automount).
#
# Usage:  ./install.sh [--wsl] [--gui] [--dry-run]
#
#   --wsl      WSL2 mode: skip compositor/audio/bluetooth packages and
#              write /etc/wsl.conf.
#   --gui      Also install the optional desktop bits (waybar, fuzzel, mako).
#              Their config is deployed either way; this flag only pulls the
#              packages, since a bare symlink is inert without the binary.
#   --dry-run  Print the full plan and exit. Changes NOTHING: no packages, no
#              keyring init, no symlinks, no /etc edits, no service changes.
#
# Environment overrides:
#   SKIP_UPGRADE=1   refresh package databases only; skip the full -Syu
#   SKIP_CHSH=1      do not attempt to change the default shell
# ──────────────────────────────────────────────

# Resolve the repo root from this script's own location so the installer
# works from a checkout anywhere, not just ~/dotfiles. Falls back to
# ~/dotfiles (and clones into it) when run from a standalone copy.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "${DOTFILES:-}" ]]; then
  if [[ -f "$SCRIPT_DIR/deploy.sh" ]]; then
    DOTFILES="$SCRIPT_DIR"
  else
    DOTFILES="$HOME/dotfiles"
  fi
fi
# Set REPO to your fork if cloning from a different location
REPO="${REPO:-https://github.com/s0nprem0/dotfiles}"

WSL_MODE=false
GUI_MODE=false
DRY_RUN=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --wsl) WSL_MODE=true; shift ;;
    --gui) GUI_MODE=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) sed -n '3,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# ── XDG base directories ──
if [[ -z "${XDG_CONFIG_HOME:-}" ]]; then
  export XDG_CONFIG_HOME="$HOME/.config"
fi

# ──────────────────────────────────────────────
# Helper functions
#
# These must be defined BEFORE first use. Bash binds a function when it
# reads that line, so calling one from earlier in the file is a fatal
# "command not found" under `set -e`.
# ──────────────────────────────────────────────

# Use C locale for predictable command output
export LC_ALL=C

info() { printf "\033[1;34m==>\033[0m %s\n" "$*"; }
ok() { printf "\033[1;32m  ✓\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m  !\033[0m %s\n" "$*"; }
err() { printf "\033[1;31m  ✗\033[0m %s\n" "$*"; }

# Packages that could not be installed; reported once at the end so a single
# renamed or missing package cannot abort the rest of the install.
PKG_FAILURES=()

# Prompt and read a yes/no answer. Returns 0 for yes, 1 for no.
# On EOF (no TTY / unattended run) it returns 1 instead of failing the script
# under `set -e`, so non-interactive runs take the safe branch by default.
confirm() {
  local prompt="$1" default="${2:-n}" ans
  if ! read -r -p "$prompt" ans; then
    printf '\n'
    return 1
  fi
  [[ -z "$ans" ]] && ans="$default"
  [[ "${ans,,}" == y* ]]
}

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

# Install packages one at a time. A single missing or renamed package must not
# abort the whole run, so failures are collected in PKG_FAILURES and surfaced
# in the final summary instead. stdout is quieted; pacman's stderr (the part
# that explains *why* a package failed) is kept.
install_pacman() {
  local pkg
  for pkg in "$@"; do
    if sudo pacman -S --needed --noconfirm "$pkg" >/dev/null; then
      ok "$pkg"
    else
      err "failed to install: $pkg"
      PKG_FAILURES+=("$pkg")
    fi
  done
}

install_aur() {
  local helper="$1" pkg
  shift
  for pkg in "$@"; do
    if "$helper" -S --needed --noconfirm "$pkg" >/dev/null; then
      ok "$pkg (AUR)"
    else
      err "failed to install: $pkg (AUR)"
      PKG_FAILURES+=("$pkg")
    fi
  done
}

# Clone the gitignored zsh plugins so the first shell does not have to.
# Mirrors the zplugin-load list in .config/zsh/plugin.zsh plus the fzf-tab
# call in .zshrc; returns non-zero if any could not be fetched.
install_zsh_plugins() {
  local -a wanted=(
    zsh-users/zsh-autosuggestions
    zsh-users/zsh-completions
    zdharma-continuum/fast-syntax-highlighting
    Aloxaf/fzf-tab
  )
  local dest="$XDG_CONFIG_HOME/zsh/plugins"
  local spec owner repo failed=()

  mkdir -p "$dest" || return 1

  for spec in "${wanted[@]}"; do
    owner="${spec%%/*}"
    repo="${spec##*/}"

    # Already vendored by an earlier run — leave it alone.
    if [[ -d "$dest/$repo" ]]; then
      ok "zsh plugin present: $repo"
      continue
    fi

    if git clone --depth=1 --quiet "https://github.com/${owner}/${repo}.git" \
         "$dest/$repo"; then
      ok "zsh plugin cloned: $repo"
    else
      err "zsh plugin failed: $owner/$repo"
      failed+=("$repo")
    fi
  done

  if (( ${#failed[@]} > 0 )); then
    warn "zsh plugins missing: ${failed[*]}"
    warn "They would be cloned on first shell start, which needs network access."
    return 1
  fi
}

install_aur_helper() {
  local helper="$1"
  if command -v "$helper" &>/dev/null; then
    return 0
  fi
  info "Installing $helper from AUR ..."
  local tmpdir
  tmpdir="$(mktemp -d)"
  # Guard the destructive cleanup: only ever remove a directory that mktemp
  # actually handed us under the system temp root.
  case "$tmpdir" in
    /tmp/*|/var/tmp/*) ;;
    *) warn "Unexpected temp path '$tmpdir'; leaving it in place"; return 1 ;;
  esac
  # Always clean up, even if the clone or makepkg fails.
  trap 'rm -rf -- "$tmpdir"' RETURN
  git clone "https://aur.archlinux.org/$helper.git" "$tmpdir/$helper" || return 1
  (cd "$tmpdir/$helper" && makepkg -si --noconfirm)
  trap - RETURN
  rm -rf -- "$tmpdir"
}

# ──────────────────────────────────────────────
# Sanity checks
# ──────────────────────────────────────────────
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  echo "This script should NOT be run as root. Use a regular user with sudo."
  exit 1
fi

if ! command -v sudo &>/dev/null; then
  echo "sudo is required. Install it first:"
  echo "  pacman -S sudo"
  exit 1
fi

# curl and git are both used below but are not present on a minimal install.
# Bootstrap them before anything tries to use them.
BOOTSTRAP_DEPS=()
for dep in curl git; do
  command -v "$dep" &>/dev/null || BOOTSTRAP_DEPS+=("$dep")
done
if (( ${#BOOTSTRAP_DEPS[@]} > 0 )); then
  info "Bootstrapping required tools: ${BOOTSTRAP_DEPS[*]}"
  sudo pacman -Sy --needed --noconfirm "${BOOTSTRAP_DEPS[@]}" \
    || { echo "Failed to install: ${BOOTSTRAP_DEPS[*]}"; exit 1; }
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
# Package lists
# ──────────────────────────────────────────────

# Official repositories
PACMAN_PKGS=(
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
  fzf fd bat zoxide eza keychain jq socat powertop libnotify
  # Git tooling + shell history
  git-delta atuin
  # Development
  base-devel git rustup
  # Qt / GTK theming
  gtk3 gtk4 qt5ct qt6ct
  # Fonts
  otf-font-awesome ttf-jetbrains-mono-nerd ttf-gohu-nerd noto-fonts
  # Auth / session
  gnome-keyring polkit-kde-agent
)

# AUR packages (installed via yay / paru)
AUR_PKGS=(
  matugen-bin         # Material You colour generator
  cloudflare-warp-bin # WARP VPN (optional, for network popup)
)

# Optional desktop bits. Config is always deployed; the packages are pulled
# only with --gui, because a symlinked config dir is inert without the binary.
GUI_PACMAN_PKGS=(
  waybar              # status bar (works on WSLg's Weston too)
  fuzzel              # app launcher / dmenu replacement
  mako                # notification daemon
)

# Never installed under WSL: the Wayland session is provided by WSLg, and
# pipewire/bluez/powertop have no meaningful WSL2 backing.
if $WSL_MODE; then
  WSL_SKIP_PACMAN=(
    pipewire wireplumber pipewire-pulse easyeffects pavucontrol playerctl
    bluez bluez-utils blueman
    networkmanager nm-connection-editor iw iwd
    grim slurp wl-clipboard
    brightnessctl power-profiles-daemon thermald
    udisks2 gvfs-mtp
    powertop
    polkit-kde-agent
  )
  WSL_SKIP_AUR=(
    cloudflare-warp-bin
  )
  remove_items PACMAN_PKGS "${WSL_SKIP_PACMAN[@]}"
  remove_items AUR_PKGS "${WSL_SKIP_AUR[@]}"
  AUR_PKGS+=(
    wslu # Windows interop utilities (wslview/wslpath) for WSLg
  )
  info "WSL mode: filtered out compositor/hardware packages"
fi

if ! $GUI_MODE; then
  remove_items PACMAN_PKGS "${GUI_PACMAN_PKGS[@]}"
  info "Optional desktop packages excluded (pass --gui to include them)"
fi

# ──────────────────────────────────────────────
# 0. Dry run
#
# Deliberately placed before *every* mutating step rather than threading a
# DRY_RUN check through each one: there is no way for this branch to miss a
# future sudo/systemctl/pacman call added later in the file.
# ──────────────────────────────────────────────
if $DRY_RUN; then
  echo ""
  echo "========================================"
  echo "  DRY RUN — no changes will be made"
  echo "========================================"

  echo ""
  echo "Repo:      $DOTFILES"
  echo "Platform:  $(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-unknown}")"
  $WSL_MODE && echo "WSL mode:  yes" || echo "WSL mode:  no"
  $GUI_MODE  && echo "GUI pkgs:  included" || echo "GUI pkgs:  excluded (--gui to include)"

  echo ""
  echo "Would install (pacman):"
  printf '    %s\n' "${PACMAN_PKGS[@]}"
  echo ""
  echo "Would install (AUR, needs a helper):"
  if (( ${#AUR_PKGS[@]} == 0 )); then
    echo "    (none)"
  else
    printf '    %s\n' "${AUR_PKGS[@]}"
  fi

  # Report the symlink plan without touching anything. deploy.sh owns the real
  # behaviour; this mirrors it closely enough to be useful as a preview.
  echo ""
  echo "Would link into ${XDG_CONFIG_HOME:-$HOME/.config}:"
  CONFIG_SRC="$DOTFILES/.config"
  if [[ -d "$CONFIG_SRC" ]]; then
    for candidate in "$CONFIG_SRC"/*/; do
      [[ -d "$candidate" ]] || continue
      name=$(basename "$candidate")
      src="${candidate%/}"
      dst="${XDG_CONFIG_HOME:-$HOME/.config}/$name"
      if [[ -L "$dst" ]]; then
        cur=$(readlink "$dst")
        if [[ "${cur%/}" = "$src" ]]; then
          state="ok (already linked)"
        else
          state="REPLACE (stale symlink)"
        fi
      elif [[ -e "$dst" ]]; then
        state="BACKUP file/dir, then link"
      else
        state="new link"
      fi
      printf '    %-32s %s\n' "$name/" "$state"
    done
    for file in .zshenv; do
      [[ -f "$DOTFILES/$file" ]] || continue
      dst="$HOME/$file"
      if [[ -L "$dst" ]]; then
        cur=$(readlink "$dst")
        if [[ "${cur%/}" = "$DOTFILES/$file" ]]; then
          state="ok (already linked)"
        else
          state="REPLACE (stale symlink)"
        fi
      elif [[ -e "$dst" ]]; then
        state="BACKUP file, then link"
      else
        state="new link"
      fi
      printf '    %-32s %s\n' "$file" "$state"
    done
  else
    echo "    (no .config directory in $CONFIG_SRC)"
  fi

  if [[ -d "$DOTFILES/etc" ]] && ! $WSL_MODE; then
    echo ""
    echo "Would copy system-wide into /etc (backing up any differing file):"
    find "$DOTFILES/etc" -type f -printf '    /etc/%P\n' 2>/dev/null || true
  fi

  if ! $WSL_MODE; then
    echo ""
    echo "Would enable system services:"
    echo "    NetworkManager, iwd, bluetooth, power-profiles-daemon, thermald, powertop"
    echo "  and user services:"
    echo "    pipewire, pipewire-pulse, wireplumber, gnome-keyring-daemon"
  fi

  echo ""
  echo "Would also: initialise the pacman keyring, ensure base-devel/git,"
  echo "ensure a Rust toolchain, install zsh plugins and opencode npm deps,"
  if [[ "${SKIP_UPGRADE:-0}" == "1" ]]; then
  echo "refresh only the package databases (SKIP_UPGRADE=1),"
  else
  echo "run a full 'pacman -Syu' (set SKIP_UPGRADE=1 to skip),"
  fi
  if [[ "${SKIP_CHSH:-0}" != "1" ]]; then
    echo "set your default shell to zsh (SKIP_CHSH=1 to skip),"
  fi
  if ! command -v cargo &>/dev/null; then
    echo "install rustup and the stable toolchain,"
  fi
  if [[ -d "$DOTFILES/primo" ]]; then
    echo "build the primo Rust helpers (cargo)."
  fi
  echo "Clean the pacman cache."
  echo ""
  echo "Nothing was changed. Re-run without --dry-run to apply."
  echo "========================================"
  exit 0
fi

# ──────────────────────────────────────────────
# 1. Bootstrap: pacman keyring + base-devel
# ──────────────────────────────────────────────
info "Initialising pacman keyring (safe to re-run) ..."
sudo pacman-key --init 2>/dev/null || true
sudo pacman-key --populate archlinux 2>/dev/null || true

# A full upgrade can pull a new kernel or bootloader-adjacent packages, which
# is a real (if reversible) change to the host. Skipped with SKIP_UPGRADE=1.
if [[ "${SKIP_UPGRADE:-0}" == "1" ]]; then
  info "Refreshing package databases only (SKIP_UPGRADE=1) ..."
  sudo pacman -Sy --noconfirm
else
  info "Updating package databases and system ..."
  sudo pacman -Syu --noconfirm
fi

info "Ensuring base-devel and git are installed ..."
sudo pacman -S --needed --noconfirm base-devel git

# ──────────────────────────────────────────────
# 2. Install official packages
# ──────────────────────────────────────────────
info "Installing official packages ..."
install_pacman "${PACMAN_PKGS[@]}"
if (( ${#PKG_FAILURES[@]} == 0 )); then
  ok "Official packages installed"
else
  err "${#PKG_FAILURES[@]} official package(s) failed — continuing so the rest of the setup still runs"
fi

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
  # shellcheck disable=SC2034  # $choice is only listed for display; $REPLY drives the case below
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
elif (( ${#AUR_PKGS[@]} == 0 )); then
  ok "No AUR packages required for this platform"
else
  install_aur "$AUR_HELPER" "${AUR_PKGS[@]}" && ok "AUR packages installed"
fi

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
  if $WSL_MODE; then
    "$DOTFILES/deploy.sh" --wsl
  else
    "$DOTFILES/deploy.sh"
  fi
  ok "Dotfiles deployed"
else
  warn "deploy.sh not found; skipping dotfile deployment"
fi

# ── Set ZDOTDIR now that zsh config exists ──
if [[ -d "$XDG_CONFIG_HOME/zsh" ]]; then
  export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
fi

# ──────────────────────────────────────────────
# 7. Build the primo Rust helpers
# ──────────────────────────────────────────────
if [[ -f "$DOTFILES/primo/Makefile" ]] && command -v cargo &>/dev/null; then
  info "Building primo Rust helpers ..."
  if make -C "$DOTFILES/primo" all; then
    ok "primo helpers built"
  else
    warn "primo helpers build failed (callers will fall back or error)"
  fi
fi

if [[ -f "$DOTFILES/.config/opencode/package.json" ]]; then
  if command -v npm &>/dev/null; then
    info "Installing opencode dependencies ..."
    (cd "$DOTFILES/.config/opencode" && npm ci --silent) && ok "opencode dependencies installed" || warn "opencode npm ci failed"
  else
    warn "npm not found; skipping opencode dependencies (install nodejs to enable)"
  fi
fi

# ──────────────────────────────────────────────
# 7b. Fetch zsh plugins
#
# plugins/ is gitignored, so a fresh checkout has none, and plugin.zsh would
# otherwise clone them from .zshrc — several network round-trips before the
# first prompt, and silently skipped when offline. Clone them here, where a
# failure is reported. The lazy path in plugin.zsh stays as a fallback.
# ──────────────────────────────────────────────
if [[ -f "$XDG_CONFIG_HOME/zsh/plugin.zsh" ]]; then
  info "Installing zsh plugins ..."
  install_zsh_plugins || warn "Some zsh plugins could not be fetched"
else
  warn "zsh config not found; skipping zsh plugins"
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

      # Never clobber a locally modified system file: keep a timestamped
      # backup first. Identical files are left alone so re-runs are no-ops.
      if sudo test -f "$target"; then
        if sudo cmp -s "$f" "$target"; then
          ok "$target (unchanged)"
          continue
        fi
        backup="$target.dotfiles.bak.$(date +%Y%m%d%H%M%S)"
        if sudo cp -p "$target" "$backup" 2>/dev/null; then
          warn "$target differs — saved your version to $backup"
        else
          warn "$target differs — could not back it up, skipping"
          continue
        fi
      fi

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
if [[ "${SKIP_CHSH:-0}" != "1" ]] && [[ "$SHELL" != "$(command -v zsh)" ]]; then
  info "Setting zsh as default shell ..."
  # chsh writes /etc/passwd, so it needs root. Without sudo it always fails
  # with "Authentication token manipulation error".
  if sudo chsh -s "$(command -v zsh)" "$(id -un)" 2>/dev/null; then
    ok "Default shell changed to zsh (log out & back in to apply)"
  else
    warn "Could not change shell. Run manually: sudo chsh -s $(command -v zsh) $(id -un)"
  fi
fi

# ──────────────────────────────────────────────
# 12. WSL-specific configuration
# ──────────────────────────────────────────────
if $WSL_MODE; then
  WSL_CONF="/etc/wsl.conf"
  sudo mkdir -p "$(dirname "$WSL_CONF")"
  sudo touch "$WSL_CONF"

  info "Configuring /etc/wsl.conf ..."
  # Only add keys that are absent, so re-runs do not accumulate duplicate
  # sections. grep is given a whitelist of spacing variants because
  # /etc/wsl.conf may legitimately be written as "systemd=true" or "systemd = true".
  wsl_conf_has() {
    sudo grep -qE "^[[:space:]]*${1}[[:space:]]*=[[:space:]]*${2}[[:space:]]*$" "$WSL_CONF"
  }

  if ! wsl_conf_has 'systemd' 'true'; then
    printf '\n[boot]\nsystemd=true\n' | sudo tee -a "$WSL_CONF" >/dev/null
    ok "/etc/wsl.conf: enabled systemd"
  fi
  if ! wsl_conf_has 'options' '"metadata"'; then
    printf '\n[automount]\noptions="metadata"\n' | sudo tee -a "$WSL_CONF" >/dev/null
    ok "/etc/wsl.conf: metadata automount (exec bits on /mnt/c)"
  fi

  # Optional Windows-side .wslconfig (global, applies to all distros)
  WSL_CONFIG=""
  if command -v cmd.exe &>/dev/null; then
    WIN_PROFILE="$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')"
    [[ -n "$WIN_PROFILE" ]] && WSL_CONFIG="$WIN_PROFILE/.wslconfig"
  fi
  if [[ -n "$WSL_CONFIG" ]] && [[ ! -f "$WSL_CONFIG" ]]; then
    echo ""
    # confirm() returns 1 on EOF, so an unattended run safely skips this
    # instead of aborting under `set -e`.
    if confirm "Create $WSL_CONFIG with recommended WSL2 settings? [y/N] " n; then
      cat > "$WSL_CONFIG" <<'EOF'
# Generated by dotfiles/install.sh --wsl
[wsl2]
dnsTunneling=true
networkingMode=mirrored
EOF
      ok "$WSL_CONFIG created"
      warn "Restart WSL from PowerShell to apply:  wsl --shutdown"
    else
      ok "Skipped .wslconfig"
    fi
  fi
fi

# ──────────────────────────────────────────────
# 13. Git + Atuin setup
# ──────────────────────────────────────────────
if [[ -d "$XDG_CONFIG_HOME/git" ]]; then
  info "Configuring git host settings ..."

  # Match the GNUPGHOME used by zsh so keys land in one place
  export GNUPGHOME="${GNUPGHOME:-$HOME/.local/share/gnupg}"
  mkdir -p "$GNUPGHOME"
  chmod 700 "$GNUPGHOME"

  # Pick the host variant (WSL vs native Arch)
  GIT_HOST_CONF="$XDG_CONFIG_HOME/git/host.gitconfig"
  if [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi microsoft /proc/version 2>/dev/null; then
    GIT_HOST_SRC="$DOTFILES/.config/git/hosts/wsl.gitconfig"
  else
    GIT_HOST_SRC="$DOTFILES/.config/git/hosts/arch.gitconfig"
  fi
  cp "$GIT_HOST_SRC" "$GIT_HOST_CONF"
  ok "host.gitconfig ← $(basename "$GIT_HOST_SRC")"

  # GPG signing: generate a key if none exists, then wire it up.
  # Both checks below are `if` conditions, so pipefail + grep -q exiting
  # early (SIGPIPE, status 141) cannot abort the script here.
  if ! gpg --list-secret-keys --with-colons 2>/dev/null | grep -q '^sec:'; then
    warn "No GPG secret key found."
    if confirm "Generate a signing key now? [Y/n] " y; then
      # Identity is taken from the repo's own git config rather than being
      # hard-coded, so a fork generates a key with the right name/email.
      GIT_NAME="$(git config --file "$DOTFILES/.config/git/config" --get user.name || true)"
      GIT_EMAIL="$(git config --file "$DOTFILES/.config/git/config" --get user.email || true)"
      if [[ -n "$GIT_NAME" && -n "$GIT_EMAIL" ]]; then
        gpg --batch --pinentry-mode loopback --passphrase '' \
          --quick-generate-key "$GIT_NAME <$GIT_EMAIL>" rsa3072 sign 0 \
          && ok "GPG key generated for $GIT_EMAIL (no passphrase; add one with: gpg --change-passphrase)"
      else
        warn "No user.name/user.email in .config/git/config; skipping key generation"
      fi
    fi
  fi

  if gpg --list-secret-keys --with-colons 2>/dev/null | grep -q '^sec:'; then
    KEY_ID="$(gpg --list-secret-keys --with-colons | awk -F: '/^sec:/ {print $5; exit}')"
    # host.gitconfig is regenerated from the template above on every run, so
    # appending here stays idempotent without a rewrite pass.
    {
      printf '\n[user]\n\tsigningkey = %s\n' "$KEY_ID"
      printf '\n[commit]\n\tgpgsign = true\n'
    } >> "$GIT_HOST_CONF"
    ok "Commit signing enabled ($KEY_ID)"
  else
    warn "Skipping signing config (no key)"
  fi

  # Import existing shell history into atuin (idempotent)
  if command -v atuin &>/dev/null && [[ -s "$HOME/.local/state/zsh/history" ]]; then
    HISTFILE="$HOME/.local/state/zsh/history" atuin import auto 2>/dev/null \
      && ok "atuin history imported" || warn "atuin import skipped"
  fi
fi

# ──────────────────────────────────────────────
# Done
# ──────────────────────────────────────────────
echo ""

# Report every package that failed. The script continued so the rest of the
# setup still ran, but this must not be mistaken for a clean install.
if (( ${#PKG_FAILURES[@]} > 0 )); then
  err "${#PKG_FAILURES[@]} package(s) failed to install:"
  printf '    %s\n' "${PKG_FAILURES[@]}"
  echo "  Check for renamed packages with:  pacman -Ss <name>"
  echo "  Re-run this script once they are resolved."
  echo ""
fi

if (( ${#PKG_FAILURES[@]} > 0 )); then
  echo "────────────────────────────────────────"
  echo "  Setup finished, with ${#PKG_FAILURES[@]} package error(s) listed above."
else
  echo "────────────────────────────────────────"
  echo "  All set!"
  echo ""
fi

if $WSL_MODE; then
  echo "  Restart your terminal or run:"
  echo "    zsh"
  echo ""
  echo "  If /etc/wsl.conf was changed, run from PowerShell:"
  echo "    wsl --shutdown"
  echo "  then reopen WSL to enable systemd."
else
  echo "  Log out and back in to:"
  echo "    - Use zsh as your default shell"
  echo ""
  echo "  Optional desktop bits are not started automatically. Once the"
  echo "  packages are installed, launch them yourself:"
  echo "    waybar &        # status bar"
  echo "    mako-notify &   # notifications"
  echo "    fuzzel          # app launcher"
  echo ""
  echo "  After logging in:"
  echo "    ./scripts/theme_switcher ~/wallpaper.jpg --reload"
  echo "────────────────────────────────────────"
fi

# Non-zero when any package failed, so CI/unattended runs notice.
(( ${#PKG_FAILURES[@]} == 0 ))
