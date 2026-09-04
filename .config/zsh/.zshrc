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


# Colors for tab-completion listings: cache `dircolors -b` output once
# (LS_COLORS is otherwise unset on Arch, leaving the list-colors zstyle empty)
LSCOLORS_CACHE="$XDG_CACHE_HOME/zsh/dircolors.zsh"
if (( $+commands[dircolors] )); then
    if [[ ! -s "$LSCOLORS_CACHE" ]]; then
        dircolors -b > "$LSCOLORS_CACHE"
    fi
    source "$LSCOLORS_CACHE"
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

# fzf-tab: replace menu select with fzf (must be after compinit)
if (( $+functions[zplugin-load] )); then
  zplugin-load Aloxaf fzf-tab
fi

# History configuration.
# When atuin is installed it owns interactive history (search, recording);
# these settings remain as the on-disk source for `atuin import auto`
# and as a fallback on machines without atuin.
HISTFILE="$XDG_STATE_HOME/zsh/history"
HISTSIZE=10000
SAVEHIST=20000

if (( !$+commands[atuin] )); then
  setopt hist_expire_dups_first # delete duplicates first when HISTFILE size exceeds HISTSIZE
  setopt hist_ignore_dups       # ignore duplicated commands history list
  setopt hist_ignore_space      # ignore commands that start with space
  setopt hist_verify            # show command with history expansion to user before running it
  setopt hist_reduce_blanks     # strip extra blanks before recording history
  setopt extended_history       # Save timestamps and command durations to the history file
  setopt inc_append_history     # Write commands to the history file *immediately*, not just when the shell exits
  #setopt share_history         # share command history data - uncomment if needed

  # force zsh to show the complete history
  alias history="history 0"
fi

# configure `time` format
TIMEFMT=$'\nreal\t%E\nuser\t%U\nsys\t%S\ncpu\t%P'


if (( $+commands[zoxide] )); then
    # Cache the init script to speed up shell startup; regenerate when the
    # binary is newer than the cache (i.e. after an upgrade)
    ZOXIDE_CACHE="$XDG_CACHE_HOME/zsh/zoxide.zsh"
    if [[ ! -s "$ZOXIDE_CACHE" || "$commands[zoxide]" -nt "$ZOXIDE_CACHE" ]]; then
        zoxide init zsh > "$ZOXIDE_CACHE"
    fi
    source "$ZOXIDE_CACHE"
fi

if (( $+commands[atuin] )); then
    # Atuin: fuzzy searchable history, bound to Up and Ctrl-R.
    # Cached like zoxide; regenerated after binary upgrades.
    ATUIN_CACHE="$XDG_CACHE_HOME/zsh/atuin.zsh"
    if [[ ! -s "$ATUIN_CACHE" || "$commands[atuin]" -nt "$ATUIN_CACHE" ]]; then
        atuin init zsh > "$ATUIN_CACHE"
    fi
    source "$ATUIN_CACHE"
fi
