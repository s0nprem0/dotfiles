# History
HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000
setopt INC_APPEND_HISTORY SHARE_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST HIST_IGNORE_DUPS HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS HIST_SAVE_NO_DUPS

# Completion
autoload -Uz compinit
if [ -n "${ZDOTDIR}/.zcompdump"(#qN.mh+24) ]; then
	compinit
else
	compinit -C
fi
zstyle ':completion:*' menu select
zstyle ':completion:*' completer _expand _complete _ignored
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# Prompt: user@host path $
PROMPT='%B%F{blue}%n@%m%f %B%~%b %F{green}$%f '
RPROMPT=''

# Performance: lazy-load heavy tools
lazy_load() {
	local cmd="$1" init="$2"
	eval "
		$cmd() {
			unfunction $cmd
			$init
			$cmd \"\$@\"
		}
	"
}

lazy_load nvm   "export NVM_DIR=\"\$HOME/.nvm\"; [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\""
lazy_load rustc "export CARGO_HOME=\"\$HOME/.cargo\"; [ -s \"\$CARGO_HOME/env\" ] && . \"\$CARGO_HOME/env\""
