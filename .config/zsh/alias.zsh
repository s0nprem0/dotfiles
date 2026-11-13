# Better ls (eza required; fall back to plain ls if absent)
if (( $+commands[eza] )); then
  alias ls='eza --icons'
  alias ll='eza -lh --icons --git'       # Detailed Listing
  alias la='eza -lah --icons --git'     # Detailed Listing including hidden files
  alias tree='eza --tree --icons'       # Tree view

fi

# WSL-specific clipboard aliases & Windows interop
if is_wsl; then
  alias pbcopy='/mnt/c/Windows/System32/clip.exe'
  # Paste from the Windows clipboard. A function (not an alias) keeps the
  # quoting sane: the PowerShell script is single-quoted so embedded double
  # quotes survive intact.
  pbpaste() {
    /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoLogo -NoProfile -c \
      '$c=Get-Clipboard -Raw; if($null -ne $c){[Console]::Out.Write($c.ToString().Replace("`r",""))}'
  }

  # Windows interop helpers. appendWindowsPath=false (and the /mnt/* PATH
  # stripping above) means bare `explorer.exe`/`cmd.exe` are NOT on PATH, so
  # invoke them by absolute path. USERPROFILE is not propagated into WSL by
  # default either, so resolve it through cmd.exe.
  alias explorer='/mnt/c/Windows/explorer.exe .'   # open current dir in Windows Explorer
  alias start='/mnt/c/Windows/System32/cmd.exe /c start'  # open files/URLs with the default Windows app
  alias winpath='wslpath -w'        # Linux path -> Windows path

  # Jump to the Windows user profile (e.g. C:\Users\name)
  cdwin() {
    local win
    win="$(/mnt/c/Windows/System32/cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')"
    [[ -n "$win" ]] && cd -- "$(wslpath "$win")"
  }

  # Open files/URLs in the default Windows browser via wslu
  if (( $+commands[wslview] )); then
    alias open='wslview'
  fi
fi

alias git_personal='git config user.email "s0nprem0@proton.me" && git config user.name "s0nprem0"'
alias git_academic='git config user.email "jaysonbulugagao@gmail.com" && git config user.name "202302986"'
