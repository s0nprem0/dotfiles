# Boilerplate
source "${ZDOTDIR}/alias.zsh" # alias
source "${ZDOTDIR}/binding.zsh" # bindings
source "${ZDOTDIR}/fzf.zsh" # fzf
source "${ZDOTDIR}/options.zsh" # options
source "${ZDOTDIR}/plugin.zsh" # plugins
source "${ZDOTDIR}/prompt.zsh" # prompt

# enable completion features
autoload -Uz compinit
compinit -C -d "$XDG_CACHE_HOME/zsh/zcompdump"

# Compile zcompdump in the background if it was updated
if [[ -s "$XDG_CACHE_HOME/zsh/zcompdump" && (! -s "${XDG_CACHE_HOME}/zsh/zcompdump.zwc" || "$XDG_CACHE_HOME/zsh/zcompdump" -nt "${XDG_CACHE_HOME}/zsh/zcompdump.zwc") ]]; then
    zcompile "$XDG_CACHE_HOME/zsh/zcompdump"
fi


# Reuse a shared ssh-agent across all WSL sessions
if command -v keychain >/dev/null 2>&1; then
    eval "$(keychain --eval --quiet ~/.ssh/id_ed25519)"
fi

zstyle ':completion:*:*:*:*:*' menu select
zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' rehash true
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
zstyle ':completion:*' use-compctl false
zstyle ':completion:*' verbose true
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'

# History configurations
HISTFILE="$XDG_STATE_HOME/zsh/history"
HISTSIZE=10000
SAVEHIST=20000
setopt hist_expire_dups_first # delete duplicates first when HISTFILE size exceeds HISTSIZE
setopt hist_ignore_dups       # ignore duplicated commands history list
setopt hist_ignore_space      # ignore commands that start with space
setopt hist_verify            # show command with history expansion to user before running it
setopt extended_history       # Save timestamps and command durations to the history file
setopt inc_append_history     # Write commands to the history file *immediately*, not just when the shell exits
#setopt share_history         # share command history data - uncomment if needed

# force zsh to show the complete history
alias history="history 0"

# configure `time` format
TIMEFMT=$'\nreal\t%E\nuser\t%U\nsys\t%S\ncpu\t%P'


if (( $+commands[zoxide] )); then
    # Cache the init script to speed up shell startup
    ZOXIDE_CACHE="$XDG_CACHE_HOME/zsh/zoxide.zsh"
    if [[ ! -f "$ZOXIDE_CACHE" ]]; then
        zoxide init zsh > "$ZOXIDE_CACHE"
    fi
    source "$ZOXIDE_CACHE"
fi
