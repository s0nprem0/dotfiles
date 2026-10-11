#!/bin/sh
set -e

# Resolve the repo root from this script's own location, so deploy works from
# a checkout anywhere rather than assuming ~/dotfiles.
DOTFILES="${DOTFILES:-$(cd -- "$(dirname -- "$0")" && pwd)}"

# Every tracked .config/ directory is deployable on both WSL and bare metal,
# so there is no per-directory skip list to maintain.

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
  if [ "$arg" = "--wsl" ]; then
    WSL_MODE=true
  fi
done
if is_wsl; then
  WSL_MODE=true
fi

if $WSL_MODE; then
  echo "WSL mode: every tracked config is deployable; nothing skipped"
fi

echo "Deploying $DOTFILES ..."
echo ""

# Symlink each config directory into XDG_CONFIG_HOME.
#
# The glob stays quoted-prefixed so paths with spaces survive, and each
# candidate is checked with -d: when "$CONFIG_SRC"/*/ matches nothing the shell
# hands back the pattern literally, whose basename is "*", and deploying that
# would create a literal "*" symlink in the config home.
CONFIG_SRC="$DOTFILES/.config"
DEPLOY_ANY=false

if [ ! -d "$CONFIG_SRC" ]; then
  echo "  warn    $CONFIG_SRC does not exist; nothing to deploy"
else
  for candidate in "$CONFIG_SRC"/*/; do
    if [ -d "$candidate" ]; then
      DEPLOY_ANY=true
      break
    fi
  done
fi

for dir in "$CONFIG_SRC"/*/; do
  if [ "$DEPLOY_ANY" != true ] || [ ! -d "$dir" ]; then
    continue
  fi
  name=$(basename "$dir")

  # The glob yields a trailing slash, but readlink reports the stored target
  # without one. Comparing the raw glob string against readlink would never
  # match, so every run would needlessly relink an already-correct symlink.
  dir="${dir%/}"

  dst="${XDG_CONFIG_HOME:-$HOME/.config}/$name"

  # Skip if already a valid symlink. Both spellings of the same target are
  # accepted ("…/zsh" and "…/zsh/"), because older runs of this script wrote the
  # trailing slash and there is no reason to churn those links just to normalise
  # them. New links are written without it.
  if [ -L "$dst" ]; then
    current=$(readlink "$dst")
    if [ "${current%/}" = "$dir" ]; then
      continue
    fi
  fi

  # Backup an existing real file/dir. A fixed "$name.bak" would be clobbered by
  # the *second* run, destroying the user's original, so the old backup rotates.
  # A symlink is not backed up: the data it points at is left untouched, and the
  # stale link itself is replaced below.
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    if [ -e "$dst.bak" ]; then
      mv "$dst.bak" "$dst.bak.previous"
    fi
    echo "  backup  $name/  →  $name.bak"
    mv "$dst" "$dst.bak"
  fi

  # -n matters: without it ln follows an existing symlink whose target still
  # exists (a renamed checkout, an old clone) and creates the new link *inside*
  # that directory, leaving $dst pointing at the stale copy.
  mkdir -p "$(dirname "$dst")"
  ln -sfn "$dir" "$dst"
  echo "  link    $name/"
done

# Symlink root-level dotfiles. Kept as a list so adding a root file later is
# a one-line change rather than a refactor.
# shellcheck disable=SC2043
for file in .zshenv; do
  src="$DOTFILES/$file"
  dst="$HOME/$file"
  [ -f "$src" ] || continue

  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    continue
  fi

  # See the config-dir loop above: symlinks are replaced, not backed up.
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    if [ -e "$dst.bak" ]; then
      mv "$dst.bak" "$dst.bak.previous"
    fi
    echo "  backup  $file  →  $file.bak"
    mv "$dst" "$dst.bak"
  fi

  ln -sfn "$src" "$dst"
  echo "  link    $file"
done

echo ""
echo "Done. Only directories in $DOTFILES/.config/ were touched."
echo ""
echo "To regenerate colours from wallpaper, run:  matugen image ~/wallpaper.jpg"
echo "To undo this deploy, run:  ./uninstall.sh --dry-run  then  ./uninstall.sh"
