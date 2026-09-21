# Dotfiles maintenance

When Álvaro asks “actualiza el repo y ejecuta actualiza X”, carry out the work:

1. Locate this repository (normally `~/dotfiles`), inspect `git status --short`
   and verify `origin` is `https://github.com/aldezex/dotfiles.git` or its SSH
   equivalent. Run `git pull --ff-only` on the intended branch. Preserve local
   edits; never reset, force-pull, auto-stash, or commit unrelated changes.
   If synchronization fails, report the conflict before applying stale files.
2. Run `./actualiza X --dry-run`, inspect the scope, then `./actualiza X`.
   The request authorizes applying that target and backing up replaced files.
3. Verify the target and report what changed, its backup path, and any remaining
   user action. For Codex run `python3 -B -m unittest discover -s tests` and
   `./actualiza codex --dry-run` (it should report no changes).

Targets: `codex`, `claude`, `terminal`, `shell`, `todo`. Run `./actualiza --help`
for arguments. `todo` applies all managed file links and Codex defaults; it does
not upgrade packages, sync Neovim, or regenerate secondary Claude accounts.
Use `setup-and-install.sh` explicitly for those broader operations.

Run on macOS/Linux, or inside WSL on Windows. Requires Python 3.11+ and Git.
Do not run these Unix hooks as a native Windows installation. Install missing
dependencies using the existing installer when authorized by the task.

`actualiza codex` preserves model, authentication, approvals, project trust,
and unrelated config; it applies only verbosity, tool-output limit, hooks,
remote-plugin/app defaults and Notion enablement. It links versioned files and
backs up conflicts under `~/.dotfiles-backup/actualiza-*`. Do not copy credentials,
transcripts, machine-local config or hook trust records into this public repo.
The command manages standard `~/.codex`; inspect a custom CODEX_HOME first.

Codex requires `/hooks` review on each machine for new hook definitions. Never
bypass trust or claim the hooks are active before that review. A new session is
needed to load updated instructions. Worktree cleanup details are in README.md.
