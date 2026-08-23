#!/bin/sh
set -e

DOTFILES="${DOTFILES:-$HOME/dotfiles}"

# Wayland-only config dirs that make no sense under WSL
WSL_SKIP_DIRS="hypr quickshell wlogout uwsm hyprland-preview-share-picker"

# ──────────────────────────────────────────────
# SAFE deploy — only creates symlinks for dirs
# that exist in the dotfiles repo.
# NEVER deletes or modifies unknown dirs.
# ──────────────────────────────────────────────

is_wsl() {
  [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qi microsoft /proc/version 2>/dev/null
}

WSL_MODE=false
for arg in "$@"; do
  [ "$arg" = "--wsl" ] && WSL_MODE=true
done
is_wsl && WSL_MODE=true

if $WSL_MODE; then
  echo "WSL mode: skipping Wayland-only configs"
fi

echo "Deploying $DOTFILES ..."
echo ""

# Symlink each config directory into XDG_CONFIG_HOME
for dir in "$DOTFILES/.config"/*/; do
  name=$(basename "$dir")

  # Skip Wayland-only dirs under WSL
  if $WSL_MODE && echo " $WSL_SKIP_DIRS " | grep -q " $name "; then
    continue
  fi

  dst="${XDG_CONFIG_HOME:-$HOME/.config}/$name"

  # Skip if already a valid symlink
  [ -L "$dst" ] && [ "$(readlink "$dst")" = "$dir" ] && continue

  # Backup existing file/dir if it's not a symlink
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    echo "  backup  $name/  →  $name.bak"
    mv "$dst" "$dst.bak"
  fi

  # Create or update symlink
  ln -sf "$dir" "$dst"
  echo "  link    $name/"
done

# Symlink root-level dotfiles
for file in .zshenv; do
  src="$DOTFILES/$file"
  dst="$HOME/$file"
  [ -f "$src" ] || continue

  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    continue
  fi

  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    echo "  backup  $file  →  $file.bak"
    mv "$dst" "$dst.bak"
  fi

  ln -sf "$src" "$dst"
  echo "  link    $file"
done

echo ""
echo "Done. Only directories in $DOTFILES/.config/ were touched."
echo ""
echo "To regenerate colours from wallpaper, run:  matugen image ~/wallpaper.jpg"
echo "To reload quickshell, run:  quickshell --reload  or  pkill -SIGUSR1 quickshell"
