# Shell strategy reference

Lookup tables for non-interactive command forms on this machine (Arch on WSL2,
zsh). Loaded on demand — the always-on rules live in `~/.config/opencode/AGENTS.md`.

Use the exact flag from the right-hand column. When a command has no
non-interactive form, stop and report rather than forcing it.

## Package managers

| Task | Command | Notes |
|------|---------|-------|
| Install (repo) | `sudo pacman -S --needed --noconfirm pkg` | `--needed` makes it idempotent |
| Install (AUR) | `paru -S --noconfirm pkg` | Untrusted PKGBUILDs; review before running |
| Full upgrade | `sudo pacman -Syu --noconfirm` | Upgrades everything — ask first, never routine |
| Installed? | `pacman -Qi pkg` | Exit 1 means not installed |
| Orphans | `pacman -Qtdq` | Review; do not autoremove unasked |
| Remove | `sudo pacman -Rns --noconfirm pkg` | Check reverse deps first |
| Holds / repo | `pacman -Si pkg`, `pacman -Qi pkg` | |
| npm install | `npm ci` | Use in a repo with a lockfile, for reproducibility |
| npm publish | `npm publish --provenance` | |
| pip | `pip install --no-input pkg` | Or set `PIP_NO_INPUT=1` |
| cargo | `cargo build --quiet` | Add `--message-format=short` to cap noise |
| go | `go build ./...` | `go mod tidy` is non-interactive |
| Docker | `docker build -t name .` | Never `-it` without a TTY; `docker compose up -d` |

## Git

| Action | Command | Notes |
|--------|---------|-------|
| Status | `git status --porcelain=v1 -b` | Machine-readable, no color |
| Diff | `git --no-pager diff --stat` | `--stat` first; full diff only if small |
| Log | `git --no-pager log --oneline -n 20` | |
| Stage | `git add <path>` | Never `-p`, `-i`, or `-A` blindly |
| Commit | `git commit -m "msg"` | Never bare `git commit` (opens editor) |
| Merge | `git merge --no-edit branch` | |
| Pull | `git pull --no-edit --ff-only` | `--ff-only` avoids a surprise merge commit |
| Push | `git push` | Never `--force` without explicit approval |
| Clone | `GIT_TERMINAL_PROMPT=0 git clone <url>` | Fails instead of prompting for credentials |
| Credential input | `git config --global credential.helper` | Never pipe a password into a prompt |
| Undo | `git restore --staged <path>` | Safer than `reset` for staging |

Never: `push --force`, `reset --hard` with uncommitted work, `clean -fdx`,
`rebase -i`, `commit --amend` on a pushed commit.

## Privileged access

```bash
sudo -n <cmd>        # runs only if no password is needed, else exits non-zero
```

`sudo -n` is the default for anything privileged. If it fails with a password
error, stop and tell the user — do not retry, do not use `sudo -S`, do not echo a
password into stdin.

`systemctl` works here (systemd is enabled in WSL). Note that services do not
start when Windows boots; that needs `wsl --shutdown` from PowerShell.

## Network and SSH

```bash
curl --max-time 15 -sSf https://example.com/api      # -f fails on HTTP errors
ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 user@host
rsync -az --timeout=30 -e 'ssh -o BatchMode=yes -o ConnectTimeout=10' src/ host:dst/
```

Never `StrictHostKeyChecking=no` — it silently accepts a changed host key.
`accept-new` accepts only unknown keys and refuses changed ones.

## File operations

| Tool | Use | Avoid |
|------|-----|-------|
| `rm` | `rm file`, `rm -r dir` | `-i` prompts; never `rm -rf` on an unverified path |
| `cp` / `mv` | `cp -a src dst` | `-i` prompts; `-n` is the safe overwrite guard |
| `mkdir` | `mkdir -p a/b/c` | |
| `tar` | `tar -xzf f.tgz -C dir` | Extraction is non-interactive by default |
| `unzip` | `unzip -o f.zip -d dir` | `-o` overwrites without prompting |
| `chmod` | `chmod +x script` | No-op on `/mnt/c` |
| Disk check | `df -h .`, `du -sh dir` | Before large downloads or builds |

Prefer the **Read/Edit/Write** tools over `sed -i`, `cat > file`, or `tr`.

## Searching and inspecting

| Instead of | Use | Cap with |
|------------|-----|---------|
| `grep -r` | `rg pattern` (respects `.gitignore`) | `rg -m 20` |
| `find` | `fd pattern` | `fd -d 2` |
| `cat bigfile` | **Read** tool | `offset` / `limit` |
| `less` | `head` / `tail` / `bat --plain` | `head -50` |
| `python` REPL | `python -c "code"` | |
| `node` REPL | `node -e "code"` | |

`bat` and `eza` add headers, line numbers, and ANSI color; use `--plain` /
`--color=never` when the output is parsed or compared.

## Never run

Editors (`vim`, `nano`, `emacs`), pagers (`less`, `more`, `man`), REPLs without
`-c`/`-e`, interactive modes (`git add -p`, `git rebase -i`), interactive shells
(`bash -i`, `zsh -i`), and anything reading stdin indefinitely.

## Per-command environment variables

Set for one command only; never globally as a hang workaround.

| Variable | Value | Effect |
|----------|-------|--------|
| `GIT_TERMINAL_PROMPT` | `0` | git fails instead of prompting for credentials |
| `PIP_NO_INPUT` | `1` | pip fails instead of prompting |
| `DEBIAN_FRONTEND` | `noninteractive` | dpkg UI (not used on Arch; kept for containers) |
| `CI` | `1` | many tools self-suppress progress UI |
| `NO_COLOR` | `1` | disables ANSI color everywhere |

## Sources

- git: `--no-edit`, `--no-pager`, `--ff-only`, `-m`, `GIT_TERMINAL_PROMPT`
- pacman: `--noconfirm`, `--needed`; `pacman -Qi`, `pacman -Qtdq`
- sudo(8): `-n` non-interactive
- ssh_config(5): `BatchMode`, `StrictHostKeyChecking=accept-new`, `ConnectTimeout`
- curl: `--max-time`, `-sSf`
- OpenCode: rules load from `AGENTS.md`; the `instructions` array in
  `opencode.json` is accepted by the schema but ignored at runtime in 2.0.22.
