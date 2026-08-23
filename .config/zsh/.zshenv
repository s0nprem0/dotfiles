# ~/.zshenv

# ---------- XDG base directories ----------
export XDG_BIN_HOME="$HOME/.local/bin"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_LIB_HOME="$HOME/.local/lib"
export XDG_STATE_HOME="$HOME/.local/state"

# ---------- Route Zsh ----------
export ZDOTDIR="${XDG_CONFIG_HOME}/zsh"

# ---------- WSL detection ----------
is_wsl() {
  [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi microsoft /proc/version 2>/dev/null
}

# ---------- Pager ----------
if command -v bat >/dev/null 2>&1; then
  export MANPAGER="bat -l man -p"
elif command -v batcat >/dev/null 2>&1; then
  export MANPAGER="batcat -l man -p"
fi

# ---------- Editor ----------
export EDITOR="nvim"
export VISUAL="nvim"

# ---------- GPG ----------
# Only meaningful in interactive sessions; avoids "not a tty" noise in scripts
if [[ -o interactive && -n "$TTY" ]]; then
  export GPG_TTY="$TTY"
fi

# ---------- PATH ----------
# typeset -U makes path/PATH arrays unique — prevents duplicate entries
# from accumulating across nested shells
typeset -U path
[[ -d "$HOME/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH"

export DOCKER_CONFIG="${XDG_CONFIG_HOME}/docker"

export GNUPGHOME="$XDG_DATA_HOME/gnupg"

# XDG_RUNTIME_DIR may be unset on WSL without systemd; provide a fallback
if [[ -z "$XDG_RUNTIME_DIR" ]]; then
  if [[ -d "/run/user/$(id -u)" ]]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
  else
    export XDG_RUNTIME_DIR="/tmp/xdg-runtime-$(id -u)"
  fi
fi
if [[ ! -d "$XDG_RUNTIME_DIR" ]]; then
  mkdir -p "$XDG_RUNTIME_DIR"
  chmod 700 "$XDG_RUNTIME_DIR"
fi

# Only set SUDO_ASKPASS if seahorse is actually installed
if [[ -f "/usr/lib/seahorse/ssh-askpass" ]]; then
  export SUDO_ASKPASS="/usr/lib/seahorse/ssh-askpass"
fi

export PATH="$HOME/.config/composer/vendor/bin:$PATH"
export PATH="$HOME/.cache/.bun/bin:$PATH"
export PATH="$HOME/.nub/bin:$PATH"

# GITHUB_TOKEN for git repo fetching in apps popup
export GITHUB_TOKEN="${GITHUB_TOKEN:-}"

# Strip Windows /mnt/* paths so Windows exes never shadow Linux tools.
# Windows interop still works via explicit .exe invocations.
if is_wsl; then
  path=("${path[@]:#/mnt/*}")
fi
