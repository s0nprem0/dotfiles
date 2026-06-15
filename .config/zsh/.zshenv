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
export GPG_TTY="${TTY:-$(tty)}"

# ---------- PATH ----------
[[ -d "$HOME/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH"

export DOCKER_CONFIG="${XDG_CONFIG_HOME}/docker"

export GNUPGHOME="$XDG_DATA_HOME/gnupg"

# XDG_RUNTIME_DIR may be unset on WSL without systemd; provide a fallback
[[ -n "$XDG_RUNTIME_DIR" ]] || export XDG_RUNTIME_DIR="/run/user/$(id -u)"

export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"

# Only set SUDO_ASKPASS if seahorse is actually installed
if [[ -f "/usr/lib/seahorse/ssh-askpass" ]]; then
  export SUDO_ASKPASS="/usr/lib/seahorse/ssh-askpass"
fi

export PATH="$HOME/.config/composer/vendor/bin:$PATH"
export PATH="$HOME/.cache/.bun/bin:$PATH"
