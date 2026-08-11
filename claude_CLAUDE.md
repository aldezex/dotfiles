# Global instructions

## MANDATORY: do not leave junk behind

Álvaro's rule (2026-07-28, after running out of disk: 266 abandoned clones of a
single repo in `/private/tmp` taking up 268 GB, and not one agent picked them
up).

**Anything you generate outside the repo is yours, and you collect it before you
finish.** That includes:

- **Clones and temporary copies** in the system temp directory — `$TMPDIR`,
  `/tmp` and `/private/tmp` on macOS; `/tmp` on Linux and WSL — or in any
  scratch area. If you `git clone` or `cp -r` the project to try something,
  delete it when you are done.
- **Git worktrees.** If you create one, remove it with `git worktree remove`
  when you finish. Check with `git worktree list` that you left none behind.
- **Build artifacts inside those copies**: `node_modules`, `target`, `.next`,
  `dist`, `build`, `__pycache__`, `.venv`. In a temporary copy those run
  1-2 GB each.
- **Docker containers, images and volumes** created for a one-off test.

### How to do it right

1. **Work inside the project whenever you can.** A worktree under
   `.claude/worktrees/` beats a loose clone in `/tmp`: it shows up in
   `git worktree list` instead of getting lost.
2. **If you need scratch space, use the session scratchpad directory**, not
   `/private/tmp` directly. The harness isolates and labels it.
3. **Before calling a task done**, check and clean up:
   ```
   git worktree list                 # any left that you created?
   ls "${TMPDIR:-/tmp}" /tmp         # any copies of yours left?
   docker ps -a && docker images     # anything left from a test?
   ```
4. **Never delete blindly.** Before removing a copy or a worktree, verify it has
   no uncommitted changes and no commits missing from the origin repo. If it
   does, leave it and tell Álvaro.

### Safety net

There is a hook (`~/.claude/hooks/session-cleanup.sh`, registered on
`SessionStart` and `SessionEnd`) that sweeps up whatever escapes. **That is not
an excuse to skip cleaning up**: it is deliberately conservative and only
deletes what it can prove is disposable — it respects anything modified in the
last hour, anything with uncommitted changes, and anything holding commits that
are not on a remote. Everything it decides to keep is recorded in
`~/.claude/session-cleanup-report.log`.
