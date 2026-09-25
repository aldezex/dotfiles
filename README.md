# dotfiles

zsh, git, Neovim, Ghostty, herdr, Claude Code and Codex. macOS, Linux and WSL.

```sh
git clone https://github.com/aldezex/dotfiles.git ~/dotfiles
cd ~/dotfiles
./setup-and-install.sh --dry-run   # report every difference, change nothing
./setup-and-install.sh
```

One script does everything: Homebrew, zsh as the login shell, the `Brewfile`,
the symlinks, and the Neovim config from [aldezex/nvim](https://github.com/aldezex/nvim).

It reconciles rather than installs. Every run compares the machine against this
repo and touches only what differs, including removing links it used to create
and no longer does. Run it twice and the second run does nothing.

When something is already at a destination and it is not our symlink, it shows
the diff and asks: take the repo's version, or keep the machine's and copy it
back here ready to commit. Nothing is overwritten without a backup in
`~/.dotfiles-backup/`.

`./setup-and-install.sh --help` for the flags.

Because these are symlinks, editing `~/.zshrc` is editing this repo.

## Windows

Work inside WSL, which is just another Linux box here. Install from the WSL
shell against the WSL `$HOME` — not from PowerShell, not over `/mnt/c`.

## Claude Code: Jev

[Jev](https://docs.typesafe.ai/llms.txt) is TypeSafe's decision model. It doesn't
write text. Given some text and typed questions, it picks an option, gives a score,
or returns the probability that something is true, in under a second for a fraction of a cent.
The reconciler links:

- the `jev` skill (`claude_skill_jev_*` → `~/.claude/skills/jev/`): `jev.py` calls
  the TypeSafe API directly (no OpenRouter), and `SKILL.md` tells Claude how to use it
  ("use Jev to sort these") and when to decide for itself;
- the model router (`router.py`), wired into `claude_settings.json` as a
  `UserPromptSubmit` hook, plus a `SessionStart` hook that switches it off;
- four helper agents (`claude_agent_jev-*` → `~/.claude/agents/`), one pinned to
  each model: `jev-tiny` Haiku, `jev-everyday` Sonnet, `jev-large` Opus,
  `jev-hardest` Fable. Secondary Claude accounts get them too.

**The API key is not in this repo.** On each machine, get one at
<https://console.typesafe.ai/keys> and store it without it ever being echoed:

```zsh
mkdir -p ~/.config/typesafe && chmod 700 ~/.config/typesafe && (umask 077; read -rs "k?TypeSafe API key: "; printf %s "$k" > ~/.config/typesafe/api_key); echo
```

Without a key, everything stays silent: the hooks exit 0 and never block a message.

### Model router

Claude Code can't switch models per message, and a hook can't change the model.
It can only add a note. So when the router is on, the hook asks Jev for the smallest
model that can do each message. Messages shorter than 4 words and `/commands` are
skipped. The hook then adds a note such as `Jev sized this as EVERYDAY, confidence
0.98`, and Claude hands the work to the matching helper agent. If Jev's confidence
is below 0.6, or the message is a follow-up that only makes sense in the
conversation, Claude handles it itself.

```text
/jev on       every message goes to Jev first
/jev off      back to normal
/jev status   ON/OFF, messages per size, Jev cost so far
```

It is **OFF by default**, and every new session (`startup`) switches it off again.
The switch is shared, so that also turns it off in sessions already open.
**While it is on, every message you send leaves the machine for TypeSafe**, so keep it
off for private work. State and counters live in
`~/.config/typesafe/router_state.json`, next to the key, outside the repo.

## Codex

The reconciler links the global `AGENTS.md`, `hooks.json`, cleanup helper,
herdr integration, and the `integraciones` / `completo` CLI profiles into
`~/.codex`. For a new machine it copies `codex_config.toml` as the initial
configuration. An existing `config.toml` stays local: trusted project paths,
account settings, and model choices are never copied into this public repo.
Credentials, session transcripts, cleanup state and logs are also local.
Python 3 and Git are required; Python is included in the Brewfile.

The defaults preserve the token-saving setup: remote plugins and apps off,
Notion off, concise responses, 3000-token tool outputs, and focused validation.
Use `codex -p integraciones` for apps/Notion or `codex -p completo` for installed
remote plugins as well. Existing machine-specific Unity/Superpowers profiles
are left alone (their versioned skill paths are not portable).

### Hook activation

After installing, open a new Codex session and use `/hooks` to review and trust
both the herdr SessionStart handler and the cleanup SessionStart/SessionEnd
handlers. Codex skips untrusted hook definitions. Trust must be reviewed again
when their definitions change; the installer does not bypass it. On an existing
configuration, ensure `[features] hooks = true` if hooks were disabled.

The herdr script is the native v7 integration from `herdr integration install
codex`, with its portable command configured in `codex_hooks.json`. Outside a
herdr pane it does nothing. Reinstalling the herdr integration may rewrite the
linked files; review the resulting diff before committing.

### Temporary worktrees and cleanup

Work in the existing checkout when possible. For temporary isolation:

```sh
python3 "${CODEX_HOME:-$HOME/.codex}/hooks/session-cleanup.py" create task-name --repo "$PWD"
# Outside an agent shell, add --session <actual Codex session ID>.
```

This creates a detached worktree beneath `~/.codex/cleanup/worktrees/` and
registers its owner using `CODEX_THREAD_ID`. Preserve work in the primary
checkout before ending the session, or create a durable branch and integrate
it later. The helper never deletes branches.

At SessionEnd, only registered worktrees whose owner has ended are eligible.
SessionStart retries leftovers from ended sessions. Cleanup requires all of:

- no other registered open session in the worktree;
- no lock, Git error, uncommitted, untracked, or ignored files;
- HEAD already reachable from the primary checkout's current HEAD;
- the original repository identity and a path within the owned cleanup root.

It uses `git worktree remove` without force. It never unlocks worktrees,
scans `/tmp`, removes Docker resources, or touches Claude/user worktrees or
Codex-native managed worktrees. Ignored build outputs deliberately prevent
automatic removal too: the agent must first remove only the disposable outputs
it created. Files such as `.env` must never be assumed disposable.

A process killed without SessionEnd remains marked open. This intentionally
keeps its resources; inspect the local registry rather than inferring death
from elapsed time. No background polling or model call is used.

```sh
python3 ~/.codex/hooks/session-cleanup.py sweep --dry-run
python3 ~/.codex/hooks/session-cleanup.py sweep
```

Reports are bounded to 400 lines in `~/.codex/cleanup/report.log`. Normal hook
execution prints nothing, so it adds no developer context. State is serialized
under a file lock to prevent simultaneous hooks from deleting the same tree.

SessionEnd is a session lifecycle event, **not the end of every answer**.
Codex runs it on normal shutdown, archival/deletion of an open conversation,
or after the documented idle/disconnected timeout. Merely switching chats
does not trigger it. Codex-native worktrees keep their native lifecycle.
See [Codex hooks](https://learn.chatgpt.com/docs/hooks).

### Validation

```sh
python3 -B -m unittest discover -s tests -v
bash -n setup-and-install.sh
./setup-and-install.sh --install --links-only --dry-run
```

Tests create isolated temporary repositories and cover deletion, dirty and
ignored files, detached commits, locks, concurrent sessions, Git errors,
unregistered trees, dry runs, and silent hook execution.

### Activating on another Windows/WSL machine

Run the installer from the Linux terminal in WSL, with the repository under
`~/dotfiles`. These Bash/Python hooks use Unix file locks and are not a native
PowerShell installation.

```sh
cd ~/dotfiles
git pull --ff-only
./setup-and-install.sh --install --links-only
python3 -B -m unittest discover -s tests
codex
```

If Git or Python 3 is missing, run the full `--install` instead of
`--links-only` to install dependencies. When the installer reports a conflict
for a Codex file, choose the repo version after reviewing the diff; it backs up
the previous file. Then review/trust the hooks with `/hooks` on this machine.
Trust and authentication do not transfer through Git.

An existing `~/.codex/config.toml` is intentionally preserved. Merge the
portable defaults from `codex_config.toml` into it to enable the same minimal
mode (do not append duplicate TOML tables or overwrite your account/project
settings). New installations receive those defaults automatically. Open a new
session after changing configuration. Run Codex inside WSL to use the WSL
configuration; this installation does not configure a separate native Windows
Codex process.

## One request to update a machine

Tell the agent (Codex, Claude, or another agent that reads `AGENTS.md`):

> En ~/dotfiles, lee AGENTS.md, actualiza el repo y ejecuta actualiza codex.

On a machine that has not pulled these instructions yet, say:

> Actualiza ~/dotfiles con git pull --ff-only conservando mis cambios locales;
> después lee AGENTS.md y ejecuta ./actualiza codex.

The agent synchronizes Git, previews the changes, applies them with backups,
and verifies the result. No further permission is needed for the requested
update; Codex's own hook-trust review still happens on each machine.

```sh
./actualiza codex --dry-run
./actualiza codex
```

Supported targets:

| Target | Files/settings applied |
| --- | --- |
| `codex` | Instructions, hooks, profiles and minimal-mode config settings |
| `claude` | Primary Claude account's managed settings, instructions, hooks, and the Jev skill and agents |
| `terminal` | Ghostty and herdr config/cheatsheet |
| `shell` | zsh, Starship and Git config/helpers |
| `todo` | All the above |

`actualiza` needs Python 3.11+ and Git. It does not pull Git itself, upgrade
packages, touch credentials, or regenerate secondary Claude accounts. Use the
full installer for those account/package operations. On Windows run it in WSL.

Unlike the bootstrap installer, `actualiza codex` also updates an **existing**
config.toml: only the six minimal-workflow settings are changed. Model choice,
reasoning, approval policy, project paths and other settings are preserved.
Unusual TOML layouts that cannot be edited safely are rejected before writing.
Backups are stored in `~/.dotfiles-backup/actualiza-*`. Repeat runs are idempotent.
