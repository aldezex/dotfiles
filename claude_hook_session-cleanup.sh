#!/usr/bin/env bash
# session-cleanup.sh — runs when a Claude Code session starts and when it ends.
#
# Deletes what agents generate and never pick up: throwaway clones in the system
# temp directory and orphaned git worktrees. Anything that cannot be removed
# safely is left alone and recorded in the report; work is never lost silently.
#
# Portable across macOS and Linux (WSL included). Assumes no absolute paths and
# no GNU-vs-BSD tool differences.
#
# Safety rules (why it does not delete more than it should):
#   1. Nothing touched in the last GRACE_MIN minutes -> a parallel session may
#      still be using it.
#   2. Nothing with uncommitted changes             -> recorded and kept.
#   3. Nothing with commits missing from a remote   -> recorded and kept.
#   4. Untouchable allowlist: sockets and live state (docker, tmux, the browser
#      bridge, and Claude's own scratchpads, which the harness manages).
#
# Set DRY_RUN=1 to see what it would do without deleting anything.

set -uo pipefail

GRACE_MIN=${GRACE_MIN:-60}
REPORT="${HOME}/.claude/session-cleanup-report.log"
DRY_RUN=${DRY_RUN:-0}

# Directories that are never touched, even if they satisfy every other rule.
PROTECTED='^(claude-[0-9]+|claude-.*|tmux-[0-9]+|docker-desktop-privileged.*|powerlog|\.X11-unix|systemd-.*)$'

# The header is written lazily, only once there is a first line worth
# recording. Otherwise every session start and end left an empty
# "=== start ===" / "=== end ===" pair and buried anything that mattered.
HEADER_WRITTEN=0
log() {
  if [ "$HEADER_WRITTEN" = "0" ]; then
    printf '\n=== %s  (cwd: %s) ===\n' \
      "$(date '+%Y-%m-%d %H:%M:%S')" "${CLAUDE_PROJECT_DIR:-$PWD}" >> "$REPORT" 2>/dev/null
    HEADER_WRITTEN=1
  fi
  printf '%s\n' "$*" >> "$REPORT" 2>/dev/null
}
say() { [ "$DRY_RUN" = "1" ] && printf '%s\n' "$*"; }

# Truncate the report to the last MAX_LOG lines so it cannot grow forever.
rotate_report() {
  local max=${MAX_LOG:-400} n
  [ -f "$REPORT" ] || return 0
  n=$(wc -l < "$REPORT" 2>/dev/null | tr -d ' ')
  [ -n "$n" ] && [ "$n" -gt "$max" ] || return 0
  tail -n "$max" "$REPORT" > "$REPORT.tmp" 2>/dev/null && mv -f "$REPORT.tmp" "$REPORT"
}

delete_it() {
  local path="$1" reason="$2"
  if [ "$DRY_RUN" = "1" ]; then
    say "WOULD DELETE  $path  ($reason)"
  else
    rm -rf -- "$path" 2>/dev/null && log "  deleted: $path ($reason)"
  fi
}

keep_it() {
  local path="$1" reason="$2"
  say "KEEPING  $path  ($reason)"
  log "  KEPT: $path -> $reason"
}

# ---------------------------------------------------------------------------
# Candidate temp directories, per operating system
# ---------------------------------------------------------------------------
# macOS: $TMPDIR (/var/folders/.../T) and /private/tmp (/tmp symlinks to it)
# Linux and WSL: /tmp
temp_roots() {
  local candidates=()
  [ -n "${TMPDIR:-}" ] && candidates+=("$TMPDIR")
  candidates+=("/tmp" "/private/tmp")

  # Deduplicate by real path: on macOS /tmp and /private/tmp are the same place.
  local seen="" r real
  for r in "${candidates[@]}"; do
    [ -d "$r" ] || continue
    real=$(cd "$r" 2>/dev/null && pwd -P) || continue
    case "|$seen|" in
      *"|$real|"*) continue ;;
    esac
    seen="$seen|$real"
    printf '%s\n' "$real"
  done
}

# Age in minutes of ONE file or directory, without relying on `find -mmin` or
# on the output format of `stat`.
touched_recently() {
  local path="$1" age
  [ -e "$path" ] || return 1
  # perl ships with macOS and with virtually every Linux distro.
  if command -v perl >/dev/null 2>&1; then
    age=$(perl -e 'print int((time - (stat($ARGV[0]))[9]) / 60)' "$path" 2>/dev/null)
    if [ -n "$age" ]; then
      [ "$age" -lt "$GRACE_MIN" ]
      return $?
    fi
  fi
  # Without perl: `find -mmin`, present in both GNU find and BSD find.
  [ -n "$(find "$path" -maxdepth 0 -mmin "-$GRACE_MIN" 2>/dev/null)" ]
}

# Is there any sign that someone is working in here right now?
#
# The mtime of the top-level directory only changes when entries are created or
# removed *in* it, so an agent can spend two hours editing inside src/ while the
# root still looks old. .git/index is rewritten by every add, status and
# checkout, and lock files only exist while git is actually running.
is_active() {
  local path="$1" f
  for f in "$path" "$path/.git/index" "$path/.git/HEAD" "$path/.git/FETCH_HEAD"; do
    touched_recently "$f" && return 0
  done
  # A live lock means work in progress no matter what the timestamps say.
  [ -e "$path/.git/index.lock" ] && return 0
  return 1
}

# Does it hold commits that exist on no remote?
#
# This used to be checked only when the remote was a filesystem path, so a clone
# of a GitHub URL carrying unpushed work skipped the rule entirely and got
# deleted. `--all --not --remotes` works for any remote, and with no remote at
# all it counts every commit, which is the cautious answer.
unpushed_commits() {
  local path="$1" n
  n=$(git -C "$path" rev-list --count --all --not --remotes 2>/dev/null)
  [ -n "$n" ] && [ "$n" != "0" ] && printf '%s' "$n"
}

# ---------------------------------------------------------------------------
# 1. Orphaned git worktrees in the current project
# ---------------------------------------------------------------------------
repo_root=$(git -C "${CLAUDE_PROJECT_DIR:-$PWD}" rev-parse --show-toplevel 2>/dev/null)
if [ -n "$repo_root" ]; then
  primary=$(git -C "$repo_root" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2; exit}')
  default_branch=main
  git -C "$repo_root" rev-parse --verify main >/dev/null 2>&1 || default_branch=master

  worktrees=()
  while IFS= read -r w; do worktrees+=("$w"); done \
    < <(git -C "$repo_root" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2}')

  for wt in "${worktrees[@]}"; do
    [ "$wt" = "$primary" ] && continue
    [ -d "$wt" ] || continue

    dirty=$(git -C "$wt" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    if [ "$dirty" != "0" ]; then
      keep_it "$wt" "$dirty uncommitted files"
      continue
    fi

    head=$(git -C "$wt" rev-parse HEAD 2>/dev/null)
    if ! git -C "$repo_root" merge-base --is-ancestor "$head" "$default_branch" 2>/dev/null; then
      ahead=$(git -C "$repo_root" rev-list --count "$default_branch".."$head" 2>/dev/null)
      keep_it "$wt" "$ahead commits not merged into $default_branch"
      continue
    fi

    if [ "$DRY_RUN" = "1" ]; then
      say "WOULD DELETE  $wt  (clean worktree, already merged into $default_branch)"
    else
      git -C "$repo_root" worktree unlock "$wt" >/dev/null 2>&1
      git -C "$repo_root" worktree remove --force "$wt" >/dev/null 2>&1 \
        && log "  worktree removed: $wt (clean and already merged)"
    fi
  done

  [ "$DRY_RUN" = "1" ] || git -C "$repo_root" worktree prune >/dev/null 2>&1
fi

# ---------------------------------------------------------------------------
# 2. Throwaway clones in the system temp directories
# ---------------------------------------------------------------------------
# Collected into an array before iterating: with `temp_roots | while read` the
# body runs in a subshell, HEADER_WRITTEN would not survive it, and the report
# would end up with one repeated header per root.
roots=()
while IFS= read -r r; do roots+=("$r"); done < <(temp_roots)

for root in "${roots[@]}"; do
  [ -d "$root" ] || continue
  say "--- scanning $root ---"

  for path in "$root"/*; do
    [ -e "$path" ] || continue
    name=$(basename "$path")

    printf '%s' "$name" | grep -qE "$PROTECTED" && continue

    # Only git clones are in scope; loose files and other people's junk stay.
    [ -e "$path/.git" ] || continue

    # Rule 1: recently touched means another session may still be using it.
    if is_active "$path"; then
      keep_it "$path" "touched less than $GRACE_MIN min ago (session may be live)"
      continue
    fi

    dirty=$(git -C "$path" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    if [ "$dirty" != "0" ]; then
      keep_it "$path" "$dirty uncommitted files"
      continue
    fi

    # Rule 3: nothing holding commits that are not already on a remote.
    ahead=$(unpushed_commits "$path")
    if [ -n "$ahead" ]; then
      keep_it "$path" "$ahead unpushed commits"
      continue
    fi

    # And when the remote is a filesystem path, check it still is one: a
    # deleted origin leaves the clone as the only copy.
    origin=$(git -C "$path" config --get remote.origin.url 2>/dev/null)
    head=$(git -C "$path" rev-parse HEAD 2>/dev/null)
    if [ -n "$origin" ] && [ -d "$origin" ] && [ -n "$head" ]; then
      if ! git -C "$origin" cat-file -e "$head" 2>/dev/null; then
        keep_it "$path" "holds commits missing from $origin"
        continue
      fi
    fi

    delete_it "$path" "stale temporary clone"
  done
done

rotate_report
exit 0
