# My dotfiles

for stowing the files


# Single configuration
stow -vt ~ nvim

# Multiple configurations
stow -vt ~ {nvim,zsh,tmux,git}

# All configurations (using bash expansion)
stow -vt ~ */
