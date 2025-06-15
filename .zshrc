# ===== Core Configuration =====
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""  # Disable OMZ theme for Starship

# ===== Plugin Configuration =====
plugins=(
  git                   # Git aliases and functions
  sudo                  # Press ESC twice to add sudo
  zsh-autosuggestions   # Predictive typing
  zsh-syntax-highlighting # Command highlighting
  fzf                   # Fuzzy finder integration
)

# ===== Completion Optimization =====
# Only regenerate compdump if older than 24 hours
autoload -Uz compinit
if [[ -n ${ZDOTDIR}/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# ===== History Settings =====
HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000
setopt appendhistory
setopt share_history
setopt hist_ignore_all_dups
setopt hist_reduce_blanks
setopt hist_ignore_space

# ===== Editor Configuration =====
# Hierarchical editor selection with full path resolution
for editor in nvim vim vi nano; do
  if (( $+commands[$editor] )); then
    export EDITOR=$(command -v $editor)
    export SUDO_EDITOR=$EDITOR
    break
  fi
done
export VISUAL='code'  # Keep VS Code as visual editor

# ===== Aliases =====
alias ls='ls --color=auto --group-directories-first'
alias ll='ls -lAh'
alias grep='grep --color=auto'
alias nv='nvim'
alias g='git'

# ===== Final Initialization =====
source $ZSH/oh-my-zsh.sh
eval "$(starship init zsh)"
