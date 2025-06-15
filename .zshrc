# Oh My Zsh path
export ZSH="$HOME/.oh-my-zsh"

# Theme (robbyrussell is default)
ZSH_THEME="minimal"

# Plugins
plugins=(
  git           # Git shortcuts
  sudo          # Double ESC to prefix with sudo
  zsh-autosuggestions  # Predictive typing
  zsh-syntax-highlighting  # Command highlighting
  fzf
)

# Load Oh My Zsh
source $ZSH/oh-my-zsh.sh

# Improved completion
autoload -Uz compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'  # Case-insensitive
compinit

# History settings
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory
setopt share_history
setopt hist_ignore_all_dups

export EDITOR='nvim'
export VISUAL='code'
export SUDO_EDITOR='nvim'

# Editor fallback
for editor in nvim code vim vi nano; do
  if command -v $editor >/dev/null; then
    export EDITOR=$editor
    export VISUAL=$editor
    export SUDO_EDITOR=$(command -v $editor)
    break
  fi
done


# Aliases
alias ls='ls --color=auto'
alias ll='ls -la'
alias grep='grep --color=auto'
alias nv='nvim'
