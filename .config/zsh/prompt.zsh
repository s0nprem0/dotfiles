autoload -Uz colors && colors
autoload -Uz vcs_info

zstyle ':vcs_info:git:*' formats '(%b)'
zstyle ':vcs_info:git:*' actionformats '(%b|%a)'

PROMPT_ALTERNATIVE=twoline

configure_prompt() {
    local venv='${VIRTUAL_ENV:+($(basename "$VIRTUAL_ENV"))}'
    local chroot='${debian_chroot:+($debian_chroot)}'

    case "$PROMPT_ALTERNATIVE" in
        twoline)
            PROMPT=$'%F{green}┌──'"$chroot$venv"$'──(%B%F{blue}%n@%m%b%f)-[%B%4~%b]\n└─%(?..%F{red}✘ %? ›%f )%(#.%F{red}#.%F{blue}$)%f '
            RPROMPT='%F{cyan}${vcs_info_msg_0_}%f'
            ;;
        oneline)
            PROMPT="$chroot$venv"$'%B%F{blue}%n@%m%b%f:%B%F{green}%~%b%f %(?..%F{red}✘%f )%(#.#.$) '
            RPROMPT='%F{cyan}${vcs_info_msg_0_}%f'
            ;;
    esac
}

toggle_oneline_prompt() {
    [[ "$PROMPT_ALTERNATIVE" == oneline ]] &&
        PROMPT_ALTERNATIVE=twoline ||
        PROMPT_ALTERNATIVE=oneline

    configure_prompt
    zle reset-prompt
}

zle -N toggle_oneline_prompt
bindkey '^[p' toggle_oneline_prompt

precmd() { vcs_info }
configure_prompt