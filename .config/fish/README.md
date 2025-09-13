# Fish Shell Config

This directory contains my Fish shell configuration and functions, managed via GNU Stow.

## Purpose
- Custom prompt, aliases, and completions

## Dependencies
- fish shell (>=3.0 recommended)
- [Optional] Fisher or Oh My Fish for plugin management

## Special Setup
- Run `stow -vt ~ fish` from the repo root to symlink configs
- For local customizations, create `config.local.fish` (gitignored)

## Platform Notes
- Use conditionals in `config.fish` for OS-specific settings

---
See comments in config files for further details.
