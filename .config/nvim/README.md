# Neovim Config

This directory contains my Neovim configuration, managed via GNU Stow.

## Purpose
- Modular, symlink-friendly Neovim setup
- Custom plugins and settings (see below)

## Dependencies
- Neovim (>=0.8 recommended)
- [Optional] Plugins managed via LazyVim or other plugin managers

## Special Setup
- Run `stow -vt ~ nvim` from the repo root to symlink configs
- For local customizations, create `lua/local.lua` (gitignored)

## Platform Notes
- Some plugins or settings may require additional system dependencies (see comments in config)

---
See comments in config files for further details.
