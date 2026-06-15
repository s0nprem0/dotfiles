# Better ls (eza required; fall back to plain ls if absent)
if (( $+commands[eza] )); then
  alias ls='eza --icons'
  alias ll='eza -lh --icons --git'       # Detailed Listing
  alias la='eza -lah --icons --git'     # Detailed Listing including hidden files
  alias tree='eza --tree --icons'       # Tree view

  # Reuse ls completions for eza (avoids defining a separate completion function)
  if (( $+functions[compdef] )); then
    compdef eza=ls
  fi
fi

# Zoxide helper (you can just type 'z', but 'cd' muscle memory is strong)
if (( $+commands[zoxide] )); then
  alias cd='z'
fi

# WSL-specific clipboard aliases
if [[ "$(uname -r)" == *microsoft* ]]; then
  alias pbcopy='/mnt/c/Windows/System32/clip.exe'
  alias pbpaste='/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoLogo -NoProfile -c "[Console]::Out.Write(\$(Get-Clipboard -Raw).ToString().Replace(\"\`r\", \"\"))"'
fi
