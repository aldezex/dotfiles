WIP

My NVIM config is [here](https://github.com/aldezex/nvim) 🌚🐕

## Install

macOS, Linux and WSL — one command, from a bare machine or an existing one:

```sh
git clone https://github.com/aldezex/dotfiles.git ~/dotfiles
cd ~/dotfiles
./setup-and-install.sh --dry-run   # report every difference, change nothing
./setup-and-install.sh
```

It is a reconciler, not an installer. Every run compares the machine against
this repo and only touches what differs, so running it twice in a row does
nothing the second time. In order it:

1. installs Homebrew (and, on Linux, the base packages Homebrew needs first);
2. installs zsh and makes it the login shell;
3. installs everything in the `Brewfile`;
4. links the files below, and **removes links this repo used to create and no
   longer does**;
5. clones the nvim config into `~/.config/nvim` and syncs its plugins.

| flag | effect |
|---|---|
| `--dry-run` | report everything, change nothing |
| `--links-only` | symlinks only: no packages, no nvim |
| `--no-deps` | skip package installation |
| `--no-nvim` | skip the nvim clone and plugin sync |
| `--prune` | also offer to uninstall packages missing from the `Brewfile` |
| `--yes` | non-interactive, the repo wins every conflict |
| `--adopt` | non-interactive, the machine wins and its version is copied back here |

### When it finds a conflict

If something is already at a destination and it is not our symlink, the script
stops and asks, offering the diff:

```
  conflict: ~/.gitconfig is a real file
  [r] use the repo version (yours is backed up)
  [l] keep this machine and copy it back into the repo
  [d] show the diff
  [s] skip for now
```

`[l]` is the interesting one: it pulls the machine's version into the repo, so
it shows up in `git status` ready to commit. Nothing is ever overwritten
without a backup under `~/.dotfiles-backup/<date>/`. With no terminal attached
the script never guesses — it lists the conflicts and exits non-zero.

Removing stale links is driven by a state file at
`~/.local/state/dotfiles/linked`, which records what the last run created. That
is what lets it tell a link it made last month from one you made yourself, and
it only ever deletes a symlink still pointing into this repo.

Because they are symlinks, editing `~/.zshrc` *is* editing this repo: changes
show up in `git status` instead of getting lost. To add a new file, drop it in
here and add its path to the `LINKS` array at the top of the script.

| repo | destination |
|---|---|
| `zshrc` | `~/.zshrc` |
| `zprofile` | `~/.zprofile` |
| `gitconfig` | `~/.gitconfig` |
| `githelpers` | `~/.githelpers` |
| `gitignore_global` | `~/.config/git/ignore` |
| `ghostty.config` | `~/.config/ghostty/config` |
| `herdr.toml` | `~/.config/herdr/config.toml` |
| `herdr-hotkeys-cheatsheet.md` | `~/.config/herdr/hotkeys-cheatsheet.md` |
| `claude_settings.json` | `~/.claude/settings.json` |
| `claude_CLAUDE.md` | `~/.claude/CLAUDE.md` |
| `claude_statusline.sh` | `~/.claude/statusline.sh` |
| `claude_hook_herdr-agent-state.sh` | `~/.claude/hooks/herdr-agent-state.sh` |
| `claude_hook_session-cleanup.sh` | `~/.claude/hooks/session-cleanup.sh` |

## Windows

There is no native Windows support: on Windows the work happens **inside WSL**,
which as far as this repo is concerned is just another Linux box. Clone and
install exactly as above, from the WSL shell and against the WSL `$HOME`
(`/home/<user>`) — not from PowerShell and not over `/mnt/c`.

Two things do differ under WSL:

- **Ghostty** runs on the Windows side, not inside WSL. `ghostty.config` still
  gets linked but nothing reads it; the terminal is configured on the host.
- **Homebrew**, if you install it, lives in `/home/linuxbrew/.linuxbrew`. The
  `zshrc` finds it on its own, the same way it finds `/opt/homebrew` on macOS.

## Dependencies

Everything the configs actually call is listed in the `Brewfile`, which
`setup-and-install.sh` runs for you. `brew bundle check` reports what is
missing without installing anything.

The git aliases (`l`, `la`, `lr`, `ruf`) additionally need `sh`, `column` and
`less`, which every system already has.

`claude_hook_herdr-agent-state.sh` is managed by herdr and gets overwritten
whenever the integration updates, so it may show up as modified without you
having touched it.
