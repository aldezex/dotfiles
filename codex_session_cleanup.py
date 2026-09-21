#!/usr/bin/env python3
"""Owned temporary worktrees only; silent lifecycle hooks, no model calls."""
import argparse
import contextlib
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time


def git(path, *args):
    return subprocess.check_output(
        ["git", "-C", str(path), *args], stderr=subprocess.PIPE, timeout=20
    ).decode().strip()


def state_dir():
    return Path(os.environ.get("CODEX_HOME", str(Path.home() / ".codex"))) / "cleanup"


@contextlib.contextmanager
def locked_state():
    root = state_dir()
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (root / "lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        path = root / "state.json"
        data = json.loads(path.read_text()) if path.exists() else {"sessions": {}, "worktrees": []}
        yield data
        pending = root / "state.tmp"
        pending.write_text(json.dumps(data, indent=2) + "\n")
        pending.replace(path)


def log(message):
    path = state_dir() / "report.log"
    previous = path.read_text().splitlines()[-399:] if path.exists() else []
    previous.append(time.strftime("%Y-%m-%d %H:%M:%S ") + message)
    path.write_text("\n".join(previous) + "\n")


def primary_repo(repo):
    common = Path(git(repo, "rev-parse", "--path-format=absolute", "--git-common-dir"))
    # Exclude bare repositories and unusual layouts instead of guessing.
    if common.name != ".git" or not common.is_dir():
        raise ValueError("A normal non-bare primary checkout is required")
    primary = common.parent.resolve()
    if Path(git(primary, "rev-parse", "--show-toplevel")).resolve() != primary:
        raise ValueError("Cannot identify primary checkout")
    return primary


def create(repo, session, name):
    if not session or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,63}", name):
        raise ValueError("Session ID and a simple worktree name are required")
    primary = primary_repo(repo)
    # Outside the checkout: never becomes an untracked file in the project.
    managed = state_dir() / "worktrees" / hashlib.sha256(str(primary).encode()).hexdigest()[:16]
    managed.mkdir(parents=True, exist_ok=True)
    target = managed / name
    with locked_state() as data:
        if target.exists() or target.is_symlink():
            raise ValueError("Worktree destination already exists")
        git(primary, "worktree", "add", "--detach", str(target), "HEAD")
        data["sessions"].setdefault(session, {"cwd": str(Path(repo).resolve()), "ended": False})
        data["sessions"][session]["ended"] = False
        data["worktrees"].append({"path": str(target.resolve()), "repo": str(primary),
                                  "session": session, "created": time.time()})
    print(target)


def removable(record, sessions):
    path, repo = Path(record["path"]), Path(record["repo"])
    managed = state_dir().resolve() / "worktrees"
    if path.is_symlink() or managed not in path.resolve().parents:
        return "outside owned worktree root or symlink"
    owner = sessions.get(record["session"], {})
    if not owner.get("ended"):
        return "owning session still open (or crashed without SessionEnd)"
    for session in sessions.values():
        cwd = Path(session["cwd"]).resolve()
        if not session.get("ended") and (cwd == path or path in cwd.parents):
            return "another session is using this worktree"
    if not path.exists():
        return "missing; metadata left for manual inspection"
    if primary_repo(path) != repo.resolve():
        return "repository identity changed"
    gitdir = Path(git(path, "rev-parse", "--absolute-git-dir"))
    if (gitdir / "locked").exists() or any(gitdir.glob("*.lock")):
        return "worktree locked or Git operation in progress"
    if git(path, "status", "--porcelain", "--untracked-files=all"):
        return "uncommitted or untracked files"
    # Ignored files may be secrets or valuable local data, not just caches.
    # The agent must explicitly remove its disposable build outputs first.
    if git(path, "ls-files", "--others", "--ignored", "--exclude-standard"):
        return "ignored files remain; inspect before removing"
    head = git(path, "rev-parse", "HEAD")
    try:
        git(repo, "merge-base", "--is-ancestor", head, "HEAD")
    except subprocess.CalledProcessError:
        return "commits not preserved in primary checkout HEAD"
    return None


def sweep(data, dry_run=False):
    retained = []
    for record in data["worktrees"]:
        try:
            reason = removable(record, data["sessions"])
            if reason:
                retained.append(record)
                if dry_run:
                    print("KEEP", record["path"], "—", reason)
                else:
                    log("KEEP " + record["path"] + " — " + reason)
            elif dry_run:
                print("WOULD REMOVE", record["path"])
                retained.append(record)
            else:
                # Never unlock, force, delete branches, prune, or run rm -rf.
                git(record["repo"], "worktree", "remove", record["path"])
                log("REMOVED " + record["path"])
        except (OSError, ValueError, subprocess.SubprocessError) as exc:
            retained.append(record)
            if not dry_run:
                log("KEEP " + record["path"] + " — check failed: " + str(exc))
    if not dry_run:
        data["worktrees"] = retained
        needed = {item["session"] for item in retained}
        data["sessions"] = {key: value for key, value in data["sessions"].items()
                            if not value.get("ended") or key in needed}


def event(payload):
    name, session = payload.get("hook_event_name"), payload.get("session_id")
    cwd = payload.get("cwd")
    if payload.get("agent_id") or name not in ("SessionStart", "SessionEnd"):
        return
    if not isinstance(session, str) or not session or not isinstance(cwd, str) or not cwd:
        return
    with locked_state() as data:
        data["sessions"][session] = {"cwd": str(Path(cwd).resolve()), "ended": name == "SessionEnd"}
        sweep(data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    add = sub.add_parser("create", help="Create and register an owned detached worktree")
    add.add_argument("name")
    add.add_argument("--repo", default=".")
    add.add_argument("--session", default=os.environ.get("CODEX_THREAD_ID"))
    sub.add_parser("hook", help="Read a Codex lifecycle event from stdin")
    clean = sub.add_parser("sweep", help="Retry cleanup of ended sessions only")
    clean.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    try:
        if args.command == "create":
            create(args.repo, args.session, args.name)
        elif args.command == "hook":
            event(json.load(sys.stdin))
        else:
            with locked_state() as data:
                sweep(data, args.dry_run)
    except (OSError, ValueError, subprocess.SubprocessError) as exc:
        if args.command == "hook":
            # Lifecycle failures are visible in the local report, never injected as context.
            state_dir().mkdir(parents=True, exist_ok=True)
            log("ERROR " + str(exc))
        else:
            parser.exit(1, str(exc) + "\n")


if __name__ == "__main__":
    main()
