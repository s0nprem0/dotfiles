#!/usr/bin/env bash
# scripts/doctor.sh — read-only health check for this dotfiles setup.
#
# Verifies the pieces install.sh/deploy.sh are supposed to provide: symlinks,
# required binaries, zsh plugins, opencode, and (on systemd hosts) services.
# Prints a per-section status and exits non-zero if anything required is missing.
#
# Usage:  ./scripts/doctor.sh [--quiet]

set -u

QUIET=false
[[ "${1:-}" == "--quiet" ]] && QUIET=true

# Resolve repo root from this script's location.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES="${DOTFILES:-$(cd -- "$SCRIPT_DIR/.." && pwd)}"

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# Counters
PASS=0; WARN=0; FAIL=0

ok()   { $QUIET || printf '  \033[1;32m✓\033[0m %s\n' "$*"; PASS=$((PASS+1)); }
warn() { $QUIET || printf '  \033[1;33m!\033[0m %s\n' "$*"; WARN=$((WARN+1)); }
err()  { printf '  \033[1;31m✗\033[0m %s\n' "$*"; FAIL=$((FAIL+1)); }
section() { $QUIET || printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }

# ── Binaries ──
section "Binaries"
for bin in zsh git nvim fzf fd bat eza zoxide atuin; do
  if command -v "$bin" &>/dev/null; then ok "$bin"; else warn "$bin (optional/missing)"; fi
done
for bin in cargo opencode; do
  if command -v "$bin" &>/dev/null; then ok "$bin"; else err "$bin (required)"; fi
done

# ── Deployed symlinks ──
section "Deployed config"
for dir in "$DOTFILES/.config"/*/; do
  [[ -d "$dir" ]] || continue
  name=$(basename "$dir")
  dir="${dir%/}"
  dst="$XDG_CONFIG_HOME/$name"
  if [[ -L "$dst" ]] && [[ "$(readlink "$dst")" == "$dir" ]]; then
    ok "$name/ linked"
  elif [[ -e "$dst" ]]; then
    warn "$name/ exists but is not linked to this repo"
  else
    err "$name/ not deployed (run deploy.sh)"
  fi
done

# ── Zsh plugins ──
section "Zsh plugins"
ZPLUGINDIR="$XDG_CONFIG_HOME/zsh/plugins"
for repo in zsh-autosuggestions zsh-completions fast-syntax-highlighting fzf-tab; do
  if [[ -d "$ZPLUGINDIR/$repo" ]]; then ok "$repo"; else warn "$repo missing (run install.sh)"; fi
done

# ── Primo ──
section "Primo helpers"
if [[ -x "$DOTFILES/primo/target/release/get_battery_status" ]] || command -v get_battery_status &>/dev/null; then
  ok "primo built"
else
  warn "primo not built (run make -C primo all)"
fi

# ── OpenCode ──
section "OpenCode"
if command -v opencode &>/dev/null; then
  if opencode plugin list 2>/dev/null | grep -q .; then
    ok "opencode plugins loaded"
  else
    warn "no opencode plugins reported"
  fi
else
  err "opencode missing"
fi

# ── Systemd (user) services, when available ──
section "Services"
is_wsl() { [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi microsoft /proc/version 2>/dev/null; }
if is_wsl; then
  ok "WSL host — audio services (pipewire/wireplumber) not expected"
elif command -v systemctl &>/dev/null && systemctl --user is-system-running &>/dev/null; then
  for svc in pipewire.service wireplumber.service; do
    if systemctl --user is-active --quiet "$svc" 2>/dev/null; then
      ok "$svc active"
    else
      warn "$svc not active"
    fi
  done
else
  warn "systemd user session not available (skipping service checks)"
fi

# ── Summary ──
echo ""
printf 'Summary: %d ok, %d warnings, %d failures\n' "$PASS" "$WARN" "$FAIL"
(( FAIL == 0 ))