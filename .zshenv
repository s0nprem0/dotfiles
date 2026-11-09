export ZDOTDIR="${HOME}/.config/zsh"

# zsh has already chosen ~/.zshenv at this point; load the real environment
# (XDG vars, PATH, is_wsl) from the ZDOTDIR copy.
[[ -f "${ZDOTDIR}/.zshenv" ]] && source "${ZDOTDIR}/.zshenv"
