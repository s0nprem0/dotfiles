typeset -gA _plugins_loaded

ZPLUGINDIR="${ZDOTDIR}/plugins"

_zplugin-msg() {
  printf '[zplugin] %s\n' "$1"
}

_zplugin-dir() {
  printf '%s/%s' "$ZPLUGINDIR" "$1"
}

zplugin-load() {
  local owner="$1"
  local repo="$2"

  local dir
  dir="$(_zplugin-dir "$repo")"

  # already loaded
  [[ -n "${_plugins_loaded[$repo]}" ]] && return

  _plugins_loaded[$repo]=1

  # install if missing
  if [[ ! -d "$dir" ]]; then
    mkdir -p "$ZPLUGINDIR"

    _zplugin-msg "installing ${repo}"

    git clone --depth=1 \
      "https://github.com/${owner}/${repo}.git" \
      "$dir" || {
        _zplugin-msg "failed installing ${repo}"
        return 1
      }
  fi

  # completions
  [[ -d "$dir/functions" ]] && fpath+=("$dir/functions")
  [[ -d "$dir/completions" ]] && fpath+=("$dir/completions")

  local entry

  for entry in \
    "$dir/${repo}.plugin.zsh" \
    "$dir/${repo}.zsh-theme" \
    "$dir/${repo}.zsh" \
    "$dir/init.zsh"
  do
    if [[ -f "$entry" ]]; then
      source "$entry"
      return
    fi
  done

  _zplugin-msg "plugin entry not found: ${repo}"
}

zplugin-update() {
  local dir

  for dir in "$ZPLUGINDIR"/*; do
    [[ -d "$dir/.git" ]] || continue

    _zplugin-msg "updating $(basename "$dir")"

    git -C "$dir" pull --ff-only --quiet || {
      _zplugin-msg "failed updating $(basename "$dir")"
    }
  done
}

zplugin-fetch() {
  local dir

  for dir in "$ZPLUGINDIR"/*; do
    [[ -d "$dir/.git" ]] || continue

    _zplugin-msg "fetching $(basename "$dir")"

    git -C "$dir" fetch --all --prune --quiet || {
      _zplugin-msg "failed fetching $(basename "$dir")"
    }
  done
}

zplugin-remove() {
  local repo="$1"

  [[ -z "$repo" ]] && {
    _zplugin-msg "usage: zplugin-remove <repo>"
    return 1
  }

  rm -rf "$(_zplugin-dir "$repo")"

  unset "_plugins_loaded[$repo]"

  _zplugin-msg "removed ${repo}"
}

# plugins
zplugin-load zsh-users zsh-autosuggestions
zplugin-load zsh-users zsh-history-substring-search

zplugin-load zdharma-continuum fast-syntax-highlighting
