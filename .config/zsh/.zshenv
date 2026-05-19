# ~/.config/zsh/.zshenv

# ---------- XDG base directories ----------
# Centralize config/cache/data locations
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

export ZDOTDIR="$HOME/.config/zsh"


# ---------- Editor ----------
# Default editor used by git, crontab, etc.
export EDITOR="nvim"
export VISUAL="nvim"

# ---------- GPG ----------
export GPG_TTY=$(tty)

# ---------- PATH ----------
# Personal binaries/scripts
export PATH="$HOME/.local/bin:$PATH"
