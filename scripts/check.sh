#!/usr/bin/env bash
# Validate the repository. Read-only: never modifies the working tree or the
# files in $HOME.
#
# Usage: scripts/check.sh
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd -- "$SCRIPT_DIR/.." && pwd)"
cd "$REPO" || exit 1

PASS=0
FAIL=0
WARN=0

pass() { printf '  ✓ %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  ✗ %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }
warn() { printf '  ! %s\n' "$1"; WARN=$((WARN + 1)); }
section() { printf '\n== %s\n' "$1"; }

# ── 1. Shell syntax ────────────────────────────────────────────────────────
section "Shell syntax"
SHELL_FILES=(
  install.sh deploy.sh uninstall.sh
  scripts/session.sh scripts/check.sh scripts/theme_switcher
  scripts/rebuild_thunar.sh
)
for f in "${SHELL_FILES[@]}"; do
  [[ -f "$f" ]] || { warn "$f missing (skipped)"; continue; }
  if bash -n "$f" 2>/tmp/opencode/check-syntax.$$; then
    pass "bash -n $f"
  else
    fail "bash -n $f"
    sed 's/^/      /' /tmp/opencode/check-syntax.$$
  fi
done
rm -f /tmp/opencode/check-syntax.$$

# ── 2. ShellCheck (optional) ───────────────────────────────────────────────
section "ShellCheck"
if command -v shellcheck >/dev/null 2>&1; then
  found=0
  for f in "${SHELL_FILES[@]}"; do
    [[ -f "$f" ]] || continue
    found=1
    if shellcheck -S warning "$f"; then
      pass "shellcheck $f"
    else
      fail "shellcheck $f"
    fi
  done
  (( found == 0 )) && warn "no shell scripts found to check"
else
  warn "shellcheck not installed — skipping (pacman -S shellcheck)"
fi

# ── 3. Git hygiene ─────────────────────────────────────────────────────────
section "Git"
if git rev-parse --git-dir >/dev/null 2>&1; then
  if git diff --check; then
    pass "git diff --check (no whitespace errors)"
  else
    fail "git diff --check"
  fi

  untracked=$(git ls-files --others --exclude-standard | head -20)
  if [[ -z "$untracked" ]]; then
    pass "no untracked files"
  else
    warn "untracked files present (not committed):"
    printf '      %s\n' $untracked
  fi

  # Secrets that must never be tracked.
  section "Secret scan"
  if git ls-files | grep -qiE '(^|/)(id_rsa|id_ed25519|\.pem|\.key|credentials|secrets?)\.?$'; then
    fail "possible secret tracked in git"
  else
    pass "no obvious secret filenames tracked"
  fi
  if git grep -qiE 'BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY' -- . 2>/dev/null; then
    fail "private key material found in tracked files"
  else
    pass "no private key material in tracked files"
  fi
else
  warn "not a git repository — skipping git checks"
fi

# ── 4. No removed-component dependencies ───────────────────────────────────
# The compositor / QML-shell layers were deleted from this repo. A *runtime*
# probe (session.sh detecting a compositor) is fine; a dependency is not.
# Excluded: this script, prose explaining the history, and comment lines — a
# note saying "this used to drive X" is documentation, not a dependency.
section "Removed-component dependencies"
QS_REFS=$(git grep -niE 'quickshell|\buwsm\b|wlogout' -- \
  ':!.config/opencode' ':!scripts/check.sh' ':!*.md' 2>/dev/null \
  | grep -vE ':\s*(#|//)' | head -20)
if [[ -z "$QS_REFS" ]]; then
  pass "no QuickShell/uWSM/wlogout dependencies"
else
  fail "leftover dependencies:"
  printf '      %s\n' "$QS_REFS"
fi

# ── 5. Theme presets are well-formed ───────────────────────────────────────
# primo/apply_preset deserialises these; a malformed or missing colour key
# silently produces a broken theme rather than an error.
section "Theme presets"
if command -v jq >/dev/null 2>&1; then
  bad=0
  for preset in .config/matugen/presets/*.json; do
    [[ -f "$preset" ]] || continue
    if ! jq -e . "$preset" >/dev/null 2>&1; then
      fail "invalid JSON: $preset"
      bad=1
      continue
    fi
    missing=$(jq -r '["bg","fg","surface","primary","error","warning","green","blue"]
                    - (.shell | keys) | join(",")' "$preset" 2>/dev/null)
    if [[ -n "$missing" ]]; then
      fail "$preset missing shell colours: $missing"
      bad=1
    fi
  done
  (( bad == 0 )) && pass "all presets valid with the required shell colours"
else
  warn "jq not installed — skipping preset validation"
fi

# ── 6. Config includes resolve ─────────────────────────────────────────────
# Two things make this non-trivial and both are real:
#   - kitty resolves a relative include against the *including file's*
#     directory, not $HOME.
#   - globinclude is optional by design; a pattern that matches nothing is
#     skipped silently, so it must not be reported as missing.
section "Config references"
missing=0
for conf in .config/kitty/kitty.conf .config/waybar/config.jsonc; do
  [[ -f "$conf" ]] || continue
  base=$(dirname "$conf")
  while read -r directive target; do
    [[ -n "$target" ]] || continue
    case "$target" in
      "~/"*) path="${target/#\~/$HOME}" ;;
      /*)    path="$target" ;;
      *)     path="$base/$target" ;;
    esac
    # An unexpanded glob is the point of globinclude: nothing must exist yet.
    if [[ "$directive" == "globinclude" || "$path" == *"*"* ]]; then
      continue
    fi
    if [[ ! -e "$path" ]]; then
      fail "$conf references a missing file: $target"
      missing=1
    fi
  done < <(sed -nE 's/^[[:space:]]*(globinclude|include)[[:space:]]+([^[:space:]]+).*/\1 \2/p' "$conf")
done
(( missing == 0 )) && pass "all required include targets exist"

# ── 7. Optional desktop components are inert without their binary ──────────
section "Optional components"
for pair in "waybar:waybar" "fuzzel:fuzzel" "mako:mako-notify"; do
  cfg="${pair%%:*}"; bin="${pair##*:}"
  if [[ -d "$REPO/.config/$cfg" ]]; then
    pass ".config/$cfg present"
  else
    warn ".config/$cfg absent (optional)"
  fi
  command -v "$bin" >/dev/null 2>&1 \
    || warn "$bin not installed — the config is inert until it is (install.sh --gui)"
done

# ── 8. primo builds ────────────────────────────────────────────────────────
section "primo (Rust)"
if [[ -f "$REPO/primo/Cargo.toml" ]] && command -v cargo >/dev/null 2>&1; then
  if (cd primo && cargo check --offline --quiet 2>/tmp/opencode/check-cargo.$$); then
    pass "cargo check"
  else
    fail "cargo check"
    tail -20 /tmp/opencode/check-cargo.$$ | sed 's/^/      /'
  fi
  rm -f /tmp/opencode/check-cargo.$$
else
  warn "primo/ or cargo missing — skipping Rust check"
fi

# ── Summary ────────────────────────────────────────────────────────────────
printf '\n%s\n' "────────────────────────────────────────"
printf '  %d passed, %d failed, %d warning(s)\n' "$PASS" "$FAIL" "$WARN"
printf '%s\n' "────────────────────────────────────────"
(( FAIL == 0 )) || exit 1