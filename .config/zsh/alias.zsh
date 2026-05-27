# Better ls
alias ls='eza --icons'
alias ll='eza -lh --icons --git'       # Detailed Listing
alias la='eza -lah --icons --git'     # Detailed Listing including hidden files
alias tree='eza --tree --icons'       # Tree view

alias cd='z' # Zoxide helper (you can just type 'z', but 'cd' muscle memory is strong)

# Reuse ls completions for eza (avoids defining a separate completion function)
if (( $+functions[compdef] )); then
    compdef eza=ls
    # Add more compdef here (git, docker, etc.)
fi
