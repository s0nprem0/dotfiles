# My dotfiles

Lightweight dotfiles repository designed for `stow`-based management.

Usage
- Single configuration:

	stow -vt ~ nvim

- Multiple configurations:

	stow -vt ~ {nvim,zsh,tmux,git}

- All configurations (using bash expansion):

	stow -vt ~ */

Secrets & config (important)
- **Never commit private keys or credentials.** Keep SSH keys, API keys, and any private data out of the repo.
- Use the `templates/` directory for repository-tracked examples, then copy them to local files that are ignored by Git.

	Example workflow:

	- Copy a template to your home directory and edit it locally:

		cp templates/gitconfig.template ~/.gitconfig.local

	- Add local files to `.gitignore` so they are never committed (see `.gitignore` in this repo).

- Consider using encrypted secret storage for shared secrets (age, GPG, git-crypt) or a secret manager / OS keychain for production credentials.

Templates included
- `templates/gitconfig.template` — personal values go into `~/.gitconfig.local` (ignored).
- `templates/ssh_config.example` — example SSH config; **do not** commit private keys referenced by this file.
- `templates/starship.toml.local.example` — local Starship overrides (ignored when copied to `starship.toml.local`).
- `templates/.env.example` — example env file; copy to `.env` and keep it ignored.

Best practices
- Add `*.key`, `*.pem`, `.env*`, and `id_rsa` to `.gitignore`.
- Use `include` or `includeIf` in your tracked `gitconfig` to load local, ignored files.
- When sharing automation, provide templates and instructions instead of secrets.

If you'd like, I can also:
- add GitHub Actions to verify no secrets are committed,
- add an example `bootstrap` script to copy templates into place,
- or run a quick scan of the repo for accidentally committed secrets.

