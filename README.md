# dotfiles

Personal dotfiles for Arch Linux, tested on Arch WSL2.

Managed with Git and deployed by symlink. `install.sh` owns packages and system
setup; `deploy.sh` owns the symlinks into `~/.config`; `uninstall.sh` reverses
it.

## Layout

```text
.
├── install.sh            # packages, services, and deploy (supports --dry-run)
├── deploy.sh             # symlink .config/* into ~/.config
├── uninstall.sh          # remove managed symlinks, optionally restore backups
├── primo/                # Rust helpers (status, daemons, theme presets)
├── etc/                  # system-wide files copied to /etc
├── scripts/
│   ├── check.sh          # validate the repo (read-only)
│   ├── session.sh        # report session, optionally start waybar/mako
│   ├── theme_switcher    # regenerate colours from a wallpaper
│   └── rebuild_thunar.sh
└── .config/              # everything deployed to ~/.config
```

| Directory    | Purpose                                            |
|--------------|----------------------------------------------------|
| `zsh/`       | Shell config (ZDOTDIR points here)                 |
| `kitty/`     | Kitty terminal                                     |
| `nvim/`      | Neovim (LazyVim-based)                             |
| `tmux/`      | Tmux                                                |
| `ranger/`    | File manager                                        |
| `atuin/`     | Shell history                                       |
| `git/`       | Git config: shared base + per-host overrides       |
| `matugen/`   | Material You colour generator and its templates     |
| `fontconfig/`| Font rules                                          |
| `gtk-3.0/`, `gtk-4.0/`, `qt5ct/`, `qt6ct/` | Toolkit theming |
| `opencode/`  | OpenCode CLI config                                |
| `waybar/`    | Optional status bar                                |
| `fuzzel/`    | Optional application launcher                      |
| `mako/`      | Optional notification daemon                       |

`waybar`, `fuzzel`, and `mako` are optional. Their config is always deployed,
but nothing starts them automatically and nothing depends on them — a missing
binary is inert, not an error.

## Install

Always preview first. `--dry-run` makes no changes at all: no packages, no
keyring init, no symlinks, no `/etc` edits, no service changes.

```sh
./install.sh --dry-run
./install.sh
```

Flags:

| Flag         | Effect                                                             |
|--------------|--------------------------------------------------------------------|
| `--dry-run`  | Print the plan and exit. Changes nothing.                           |
| `--wsl`      | WSL2 mode: skip compositor/audio/bluetooth packages, write `/etc/wsl.conf`. |
| `--gui`      | Also install waybar, fuzzel, and mako.                             |

Environment overrides: `SKIP_UPGRADE=1` (refresh package DBs only, no full
`-Syu`), `SKIP_CHSH=1` (do not change your default shell).

The installer never runs as root and never replaces `~/.config` wholesale — it
only manages the directories this repo tracks.

## Update

```sh
git pull
./install.sh --dry-run
./install.sh
```

Deploying is idempotent: a config dir that is already linked to the right place
is left untouched.

## Roll back

```sh
./uninstall.sh --dry-run              # show what would be removed
./uninstall.sh                        # remove only managed symlinks
./uninstall.sh --restore-backups      # also move *.bak back into place
```

Only a symlink pointing into this repo is removed. A real directory or file in
its place is left alone, and restoring a backup never overwrites something that
already exists — newer user edits win.

## Validate

```sh
scripts/check.sh
```

Checks shell syntax, ShellCheck (if installed), `git diff --check`, untracked
files, secret scanning, leftover references to removed components, that config
includes resolve, and that `primo` compiles. It is read-only.

## Git workflow

```sh
git status
git diff
git add config scripts install.sh README.md   # adapt to the real paths
git diff --cached
git commit -m "Describe the change"
git log --oneline -10
```

Stage explicit paths. `git add -A` will happily stage unrelated work.

## WSL

Tested on Arch WSL2 (`Arch Linux` + WSLg).

`./install.sh --wsl` skips audio, Bluetooth, and hardware packages that have no
useful WSL2 backing, adds `wslu` for Windows interop, and writes `/etc/wsl.conf`
with `systemd=true` and `metadata` automount.

After changing `/etc/wsl.conf` or `.wslconfig`, restart from PowerShell:

```powershell
wsl --shutdown
```

Shell behaviour under WSL:

- Windows `/mnt/*` entries are stripped from `PATH`, so Windows executables
  never shadow Linux tools. Interop still works via explicit `.exe` paths.
- `pbcopy`/`pbpaste`, tmux yank, and nvim clipboard route through `clip.exe`.
- Interop aliases: `explorer`, `start`, `winpath`, `cdwin`, `open`.

Start a session explicitly rather than from `.zprofile`; see
`scripts/session.sh`.

## Theming

Colours come from `matugen`, driven by `scripts/theme_switcher`:

```sh
scripts/theme_switcher ~/wallpaper.jpg          # regenerate
scripts/theme_switcher ~/wallpaper.jpg --reload # …and reload running kitty
```

Generated files (`kitty/themes/matugen.conf`, `gtk-*.css`,
`opencode/themes/matugen.json`, `~/.cache/matugen/`) are gitignored. A committed
fallback palette ships in `kitty/themes/`, so kitty is styled before the first
theme run.