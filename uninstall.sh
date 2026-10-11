#!/usr/bin/env bash
# Remove the symlinks this repository manages, and restore any backup it took.
#
# Scope is deliberately narrow: only paths under .config/ in this repo are ever
# considered, and only a symlink pointing *into* this repo is removed. A real
# directory or file in its place is left alone unless --restore-backups is
# given, so hand-made config is never destroyed.
#
# Usage:
#   ./uninstall.sh --dry-run     # report the plan, change nothing
#   ./uninstall.sh               # remove managed symlinks
#   ./uninstall.sh --restore-backups   # also move *.bak back into place
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES="${DOTFILES:-$SCRIPT_DIR}"
CONFIG_SRC="$DOTFILES/.config"

DRY_RUN=false
RESTORE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --restore-backups) RESTORE=true; shift ;;
    -h|--help) sed -n '2,13p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  echo "This script should NOT be run as root." >&2
  exit 1
fi

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
ROOT_FILES=(.zshenv)

info()  { printf '%s\n' "  $1"; }
warn()  { printf '  ! %s\n' "$1" >&2; }
ok()    { printf '  ✓ %s\n' "$1"; }

[[ -d "$CONFIG_SRC" ]] || { echo "No .config directory in $DOTFILES; nothing to undo."; exit 0; }

removed=0
kept=0

echo ""
echo "Repo:     $DOTFILES"
echo "Config:   $CONFIG_HOME"
$DRY_RUN && echo "Mode:     DRY RUN — nothing will be changed"
echo ""

# ── Config directories ─────────────────────────────────────────────────────
echo "Config directories:"
for candidate in "$CONFIG_SRC"/*/; do
  [[ -d "$candidate" ]] || continue
  name=$(basename "$candidate")
  src="${candidate%/}"
  dst="$CONFIG_HOME/$name"

  if [[ ! -e "$dst" && ! -L "$dst" ]]; then
    info "$name/  (not present)"
    kept=$((kept + 1))
    continue
  fi

  if [[ ! -L "$dst" ]]; then
    # A real directory here is not ours to delete.
    warn "$name/ is a real directory, not a managed symlink — left alone"
    kept=$((kept + 1))
    continue
  fi

  target=$(readlink "$dst")
  # Only unlink if it actually points into this repo. Anything else is the
  # user's own link and is out of scope.
  case "${target%/}" in
    "$CONFIG_SRC"/*) ;;
    *)
      warn "$name/ points outside this repo ($target) — left alone"
      kept=$((kept + 1))
      continue
      ;;
  esac

  if $DRY_RUN; then
    info "would unlink  $name/  ->  $target"
  else
    rm -f -- "$dst"
    info "unlinked $name/"
  fi
  removed=$((removed + 1))
done

# ── Root-level dotfiles ────────────────────────────────────────────────────
echo ""
echo "Root files:"
for file in "${ROOT_FILES[@]}"; do
  src="$DOTFILES/$file"
  dst="$HOME/$file"
  [[ -f "$src" ]] || continue

  if [[ ! -e "$dst" && ! -L "$dst" ]]; then
    info "$file  (not present)"
    continue
  fi
  if [[ ! -L "$dst" ]]; then
    warn "$file is a real file, not a managed symlink — left alone"
    continue
  fi

  target=$(readlink "$dst")
  if [[ "${target%/}" != "${src%/}" ]]; then
    warn "$file points elsewhere ($target) — left alone"
    continue
  fi

  if $DRY_RUN; then
    info "would unlink  $file  ->  $target"
  else
    rm -f -- "$dst"
    info "unlinked $file"
  fi
  removed=$((removed + 1))
done

# ── Restore backups ────────────────────────────────────────────────────────
# deploy.sh rotates the original to <name>.bak and the previous one to
# <name>.bak.previous. Only move a backup back when the slot is now empty, so
# a newer user-created file is never clobbered.
if $RESTORE; then
  echo ""
  echo "Backups:"
  for candidate in "$CONFIG_SRC"/*/; do
    [[ -d "$candidate" ]] || continue
    name=$(basename "$candidate")
    for bak in "$CONFIG_HOME/$name.bak" "$CONFIG_HOME/$name.bak.previous"; do
      [[ -e "$bak" ]] || continue
      target="$CONFIG_HOME/$name"
      if [[ -e "$target" || -L "$target" ]]; then
        warn "$(basename "$bak") kept: $name already exists (not clobbering it)"
        continue
      fi
      if $DRY_RUN; then
        info "would restore $name  <-  $(basename "$bak")"
      else
        mv -- "$bak" "$target"
        info "restored $name  <-  $(basename "$bak")"
      fi
    done
  done
fi

echo ""
if $DRY_RUN; then
  echo "Dry run: $removed managed link(s) would be removed, $kept left alone."
  echo "Re-run without --dry-run to apply."
else
  ok "$removed managed link(s) removed, $kept left alone."
  if ! $RESTORE; then
    echo "Backups (*.bak) were kept. Restore them with: ./uninstall.sh --restore-backups"
  fi
fi