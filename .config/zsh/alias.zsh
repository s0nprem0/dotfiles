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

# WSL-specific clipboard aliases & Windows interop
if is_wsl; then
  alias pbcopy='/mnt/c/Windows/System32/clip.exe'
  alias pbpaste='/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoLogo -NoProfile -c "[Console]::Out.Write(\$(Get-Clipboard -Raw).ToString().Replace(\"\`r\", \"\"))"'

  # Windows interop helpers
  alias explorer='explorer.exe .'   # open current dir in Windows Explorer
  alias start='cmd.exe /c start'    # open files/URLs with the default Windows app
  alias winpath='wslpath -w'        # Linux path -> Windows path

  # Jump to the Windows user profile (e.g. C:\Users\name)
  cdwin() {
    local win="${USERPROFILE:-}"
    [[ -n "$win" ]] && cd -- "$(wslpath "$win")"
  }

  # Open files/URLs in the default Windows browser via wslu
  if (( $+commands[wslview] )); then
    alias open='wslview'
  fi
fi

alias git_personal='git config --global user.email "s0nprem0@proton.me" && git config --global user.name "s0nprem0"'
alias git_academic='git config --global user.email "jaysonbulugagao@gmail.com" && git config --global user.name "202302986"'
