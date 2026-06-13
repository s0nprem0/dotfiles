autoload -Uz colors vcs_info add-zsh-hook
colors

# Git configuration
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:*' check-for-changes true

zstyle ':vcs_info:git:*' unstagedstr '*'
zstyle ':vcs_info:git:*' stagedstr '+'

zstyle ':vcs_info:git:*' formats '(%b%c%u)'
zstyle ':vcs_info:git:*' actionformats '(%b|%a%c%u)'

PROMPT_ALTERNATIVE=twoline

configure_prompt() {
    local venv='${VIRTUAL_ENV:+(${VIRTUAL_ENV:t})}'

    case "$PROMPT_ALTERNATIVE" in
        twoline)
            PROMPT=$'%F{green}┌──'
            PROMPT+="$venv"
            PROMPT+=$'──(%B%F{blue}%n@%m%b%f)-[%B%4~%b]\n'
            PROMPT+=$'└─%(#.%B%F{red}#%b.%F{blue}$)%f '
            RPROMPT='%F{cyan}${vcs_info_msg_0_}%f'
            ;;
        oneline)
            PROMPT="$venv"
            PROMPT+=$'%B%F{blue}%n@%m%b%f:'
            PROMPT+=$'%B%F{green}%4~%b%f '
            PROMPT+=$'%(#.%B%F{red}#%b.%F{blue}$)%f '
            RPROMPT='%F{cyan}${vcs_info_msg_0_}%f'
            ;;
    esac
}

toggle_oneline_prompt() {
    if [[ "$PROMPT_ALTERNATIVE" == oneline ]]; then
        PROMPT_ALTERNATIVE=twoline
    else
        PROMPT_ALTERNATIVE=oneline
    fi

    configure_prompt
    zle reset-prompt
}

zle -N toggle_oneline_prompt
bindkey '^[p' toggle_oneline_prompt

add-zsh-hook precmd vcs_info

configure_prompt

