
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

zstyle ':completion:*:*:*:*:*' menu select
zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
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
#setopt share_history         # share command history data - uncomment if needed

# force zsh to show the complete history
alias history="history 0"

# configure `time` format
TIMEFMT=$'\nreal\t%E\nuser\t%U\nsys\t%S\ncpu\t%P'



# Import Composer
export PATH="$HOME/.config/composer/vendor/bin:$PATH"

export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent"
export PATH="$HOME/.cache/.bun/bin:$PATH"

# --- NEW ADDITIONS ---
# Initialize zoxide (smart cd) and fzf (fuzzy finder)
eval "$(zoxide init zsh)"
# fzf init is handled by fzf.zsh