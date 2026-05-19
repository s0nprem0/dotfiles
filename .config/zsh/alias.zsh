# Better ls
alias ls='eza --icons'
alias ll='eza -lh --icons -git'       # Detailed Listing
alias la='eza -lah --icons --git'     # Detailed Listing including hidden files
alias tree='eza --tree --icons'       # Tree view

# Reuse ls completions for eza (avoids defining a separate completion function)
compdef eza=ls
