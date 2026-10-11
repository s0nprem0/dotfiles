# Global agent rules

Personal rules for every session on this machine. They are not suggestions — if a
rule here conflicts with a task instruction, say so before proceeding.

Environment: **Arch Linux on WSL2**, systemd enabled, shell is **zsh**, OpenCode 2.

## Shell commands run non-interactively

No TTY, no `.zshrc`. Aliases and interactive PATH tweaks are absent, so `ls` is
real `ls`, not `eza`. Anything that waits for input, opens a pager, or starts an
editor will hang until it is killed.

## Bound every command

Wrap anything that might block in `timeout`:

```bash
timeout 30 git fetch          # exit 124 == killed, treat as failure, not success
timeout 60 curl --max-time 15 -sSf https://api.example.com/health
```

Also set the tool's own timeout where one exists — `curl --max-time`,
`ConnectTimeout=10` for ssh/rsync, `--timeout` for package managers.

**Never run a server or long-lived process in the foreground.** `npm run dev`,
`docker compose up`, `ssh -t`, a REPL, `tail -f`. Background it, send output to a
log, then read the log:

```bash
npm run dev > /tmp/dev.log 2>&1 &
sleep 3; tail -20 /tmp/dev.log
```

## Cap output

Unbounded output is the fastest way to waste a context window. It is the most
common real failure here, more than hangs.

- Bound listers and readers: `head -50`, `tail -30`, `git log -n 20`,
  `rg -m 20`, `fd -d 2 | head`.
- `wc -l` before printing something unknown. Do not `cat` a file you have not
  sized — use the **Read** tool, which takes `offset`/`limit`.
- Long builds: redirect to a log and grep the log, never stream it.
  `npm ci > /tmp/ci.log 2>&1; tail -40 /tmp/ci.log`
- Disable color when output will be parsed or compared: `--color=never`.
- For edits use **Read**/**Edit**/**Write**/**Grep**/**Glob**, not `sed -i`,
  `cat >`, or `grep -r`. Shell is for building, testing, and inspecting.

## Never blanket-approve a prompt

`yes |`, heredoc-fed answers, `sudo -S`, `--force` on an unknown tool. These
convert a visible stop into a silent wrong action.

In order of preference:

1. The tool's own non-interactive flag (`pacman -S --noconfirm`, `git commit -m`).
2. Fail fast and visibly — `sudo -n <cmd>` exits non-zero if a password is needed.
3. Stop and report what needs the user's credentials or approval.

## Be destructive only after verifying

`rm -rf`, `git reset --hard`, `git clean`, `pacman -R`, force-push, history
rewrites: confirm the target exists and is what you think it is (`ls -d` the path)
before running, and ask first if it touches work that is not committed. Never
build a destructive command from an unvalidated variable.

## Keep secrets out of commands

No tokens in argv — they land in `ps` output and shell history. Use environment
variables. Never `cat` a credential file, never echo a secret to verify it, never
write one into a log or a committed file.

## Git safety rails

Never `push --force`, `reset --hard` over uncommitted work, `clean -fdx`, or amend
a pushed commit without asking. Default to `git --no-pager`. Check `git status`
before and after anything history-changing, and report what actually changed.

## WSL2 specifics

- **Do not do heavy I/O under `/mnt/c`.** It is a 9p/DrvFs mount and is one to
  two orders of magnitude slower than ext4. Copy to `~/` or `/tmp` first, build
  there, copy results back.
- **File watchers do not fire across `/mnt/c`.** inotify has no inotify there, so
  `--watch` (vitest, jest, tailwind, nvim) appears to hang. Use a polling watch or
  move the project into the Linux filesystem.
- `chmod +x` is a no-op on `/mnt/c`; run scripts via their interpreter.
- Convert paths with `wslpath -w` / `wslpath -u`. Call Windows binaries by their
  `/mnt/c/.../name.exe` path.
- Windows-side repos get CRLF line endings; check `core.autocrlf` before
  committing across the boundary.

## zsh is not bash

The shell is zsh, so two silent differences bite:

- **No word splitting.** `for x in $var` iterates once in zsh, once per word in
  bash. Use an array, or `${=var}` to force splitting.
- **Unmatched globs are a hard error.** `rm *.log` fails with "no matches found"
  when no log exists, instead of passing the literal string through.

For anything multi-line or loop-heavy, write it as `bash -c '...'` rather than
assuming bash semantics.

## Verify, do not assume

Check before acting: `command -v <tool>`, `pacman -Qi <pkg>`, `test -e <path>`.
A command that reports success is not proof — read the output, and check the exit
code. Report what you verified and what you skipped.

## Per-command reference

`/home/jllyn/.config/opencode/instructions/shell-strategy.md` — exact
non-interactive flags for pacman, paru, git, npm, cargo, docker, ssh, curl, and
the other tools on this box. Read it with the **Read** tool when you need the
specific flag for a specific command; skip it for routine work.
