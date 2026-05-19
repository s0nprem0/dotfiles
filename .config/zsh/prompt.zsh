autoload -Uz colors && colors
setopt prompt_subst

PROMPT_ALTERNATIVE=twoline

configure_prompt() {
    local venv='${VIRTUAL_ENV:+($(basename "$VIRTUAL_ENV"))}'
    local chroot='${debian_chroot:+($debian_chroot)}'

    case "$PROMPT_ALTERNATIVE" in
        twoline)
            PROMPT=$'%F{green}┌──'"$chroot$venv"$'──(%B%F{blue}%n@%m%b%f)-[%B%4~%b]\n└─%(#.%F{red}#.%F{blue}$)%f '
            ;;
        oneline)
            PROMPT="$chroot$venv"$'%B%F{blue}%n@%m%b%f:%B%F{green}%~%b%f %(#.#.$) '
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

configure_prompt