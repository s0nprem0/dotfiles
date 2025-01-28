#!/bin/sh
set -e

DOTFILES="${DOTFILES:-$HOME/dotfiles}"

# Clone if needed
if [ ! -d "$DOTFILES/.git" ]; then
  echo "Cloning dotfiles..."
  git clone https://github.com/s0nprem0/dotfiles "$DOTFILES"
fi

cd "$DOTFILES"

# Sync tracked files to $HOME using symlinks
git ls-files | while IFS= read -r file; do
  # Skip repo-internal files
  case "$file" in
  .gitignore | bootstrap.sh | .github/*) continue ;;
  esac

  src="$PWD/$file"
  dst="$HOME/$file"

  mkdir -p "$(dirname "$dst")"

  if [ -f "$dst" ] && [ ! -L "$dst" ]; then
    echo "  backup  $dst → $dst.bak"
    mv "$dst" "$dst.bak"
  fi

  ln -sf "$src" "$dst"
  echo "  link    $file"
done

echo "Done."
