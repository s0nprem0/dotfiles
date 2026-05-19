# =========================================================
# fzf
# =========================================================

export FZF_DEFAULT_COMMAND='fd --type f --hidden'

export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

export FZF_DEFAULT_OPTS='
--height=60%
--layout=reverse
--border=rounded
--prompt="files > "
--pointer=">"
--preview-window=right:65%:wrap:border-left
'

if command -v bat >/dev/null; then
  export FZF_PREVIEW='bat --color=always --style=plain,numbers --line-range=:500 -- {}'
else
  export FZF_PREVIEW='sed -n "1,500p" {}'
fi

export FZF_CTRL_T_OPTS="--preview \"$FZF_PREVIEW\""

_fzf_file_no_hidden() {
  local result

  result=$(
    fd --type f |
    fzf --preview "$FZF_PREVIEW"
  ) || return

  LBUFFER+="$result"
  zle reset-prompt
}

zle -N _fzf_file_no_hidden
bindkey '^[f' _fzf_file_no_hidden
