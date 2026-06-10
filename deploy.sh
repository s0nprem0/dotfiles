#!/bin/sh
set -e

DOTFILES="${DOTFILES:-$HOME/dotfiles}"

# ──────────────────────────────────────────────
# SAFE deploy — only creates symlinks for dirs
# that exist in the dotfiles repo.
# NEVER deletes or modifies unknown dirs.
# ──────────────────────────────────────────────

echo "Deploying $DOTFILES ..."
echo ""

# Symlink each config directory into ~/.config/
for dir in "$DOTFILES/.config"/*/; do
  name=$(basename "$dir")
  dst="$HOME/.config/$name"

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

# Build quickshell Rust helpers
if [ -f "$DOTFILES/.config/quickshell/helpers_rs/Makefile" ]; then
  echo ""
  echo "  build   quickshell/helpers_rs/"
  make -C "$DOTFILES/.config/quickshell/helpers_rs" 2>/dev/null && echo "  done" || echo "  (build skipped)"
fi

echo ""
echo "Done. Only directories in $DOTFILES/.config/ were touched."
echo ""
echo "To regenerate colours from wallpaper, run:  matugen image ~/wallpaper.jpg"
echo "To reload quickshell, run:  quickshell --reload  or  pkill -SIGUSR1 quickshell"
