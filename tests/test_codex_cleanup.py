import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / "codex_session_cleanup.py"
spec = importlib.util.spec_from_file_location("cleanup", SCRIPT)
cleanup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cleanup)


class CleanupTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="codex-cleanup-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.env = patch.dict(os.environ, {"CODEX_HOME": str(self.root / "codex"),
                                          "GIT_CONFIG_GLOBAL": os.devnull,
                                          "GIT_CONFIG_NOSYSTEM": "1"})
        self.env.start()
        self.addCleanup(self.env.stop)
        self.repo = self.root / "repo with spaces"
        self.repo.mkdir()
        cleanup.git(self.repo, "init", "-b", "main")
        cleanup.git(self.repo, "config", "user.name", "Test")
        cleanup.git(self.repo, "config", "user.email", "test@example.invalid")
        (self.repo / "file").write_text("initial\n")
        (self.repo / ".gitignore").write_text(".env\nnode_modules/\n")
        cleanup.git(self.repo, "add", ".")
        cleanup.git(self.repo, "commit", "-m", "initial")

    def create(self, name="task", session="owner"):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            cleanup.create(self.repo, session, name)
        return Path(output.getvalue().strip())

    def event(self, name, session="owner", cwd=None):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            cleanup.event({"hook_event_name": name, "session_id": session,
                           "cwd": str(cwd or self.repo)})
        self.assertEqual(output.getvalue(), "")

    def test_clean_integrated_worktree_is_removed_on_end(self):
        wt = self.create()
        self.event("SessionEnd")
        self.assertFalse(wt.exists())
        self.assertTrue(self.repo.exists())
        self.assertNotIn(str(wt), cleanup.git(self.repo, "worktree", "list", "--porcelain"))

    def test_open_owner_is_preserved_on_other_session_start(self):
        wt = self.create()
        self.event("SessionStart", "other")
        self.assertTrue(wt.exists())

    def test_parallel_session_protects_worktree_until_it_ends(self):
        wt = self.create()
        self.event("SessionStart", "other", wt)
        self.event("SessionEnd")
        self.assertTrue(wt.exists())
        self.event("SessionEnd", "other", wt)
        self.assertFalse(wt.exists())

    def test_dirty_tracked_file_is_preserved(self):
        wt = self.create()
        (wt / "file").write_text("valuable edit")
        self.event("SessionEnd")
        self.assertEqual((wt / "file").read_text(), "valuable edit")

    def test_untracked_file_is_preserved(self):
        wt = self.create()
        (wt / "notes").write_text("valuable notes")
        self.event("SessionEnd")
        self.assertTrue((wt / "notes").exists())

    def test_ignored_secret_and_build_output_are_preserved(self):
        wt = self.create()
        (wt / ".env").write_text("not a real secret")
        self.event("SessionEnd")
        self.assertTrue((wt / ".env").exists())

    def test_unique_detached_commit_is_preserved(self):
        wt = self.create()
        (wt / "file").write_text("committed work")
        cleanup.git(wt, "commit", "-am", "work")
        self.event("SessionEnd")
        self.assertTrue(wt.exists())
        # Integration into the primary checkout makes a later sweep safe.
        cleanup.git(self.repo, "merge", "--ff-only", cleanup.git(wt, "rev-parse", "HEAD"))
        self.event("SessionStart", "new")
        self.assertFalse(wt.exists())

    def test_locked_worktree_is_preserved(self):
        wt = self.create()
        cleanup.git(self.repo, "worktree", "lock", str(wt))
        self.event("SessionEnd")
        self.assertTrue(wt.exists())
        self.assertIn("locked", cleanup.git(self.repo, "worktree", "list", "--porcelain"))

    def test_unregistered_worktree_is_never_touched(self):
        wt = self.root / "other-agent"
        cleanup.git(self.repo, "worktree", "add", "--detach", str(wt))
        self.event("SessionEnd")
        self.assertTrue(wt.exists())

    def test_git_failure_preserves_worktree(self):
        wt = self.create()
        with patch.object(cleanup, "primary_repo", side_effect=OSError("unavailable")):
            self.event("SessionEnd")
        self.assertTrue(wt.exists())

    def test_dry_run_does_not_remove_eligible_worktree(self):
        wt = self.create()
        with cleanup.locked_state() as data:
            data["sessions"]["owner"]["ended"] = True
        with cleanup.locked_state() as data, contextlib.redirect_stdout(io.StringIO()) as out:
            cleanup.sweep(data, dry_run=True)
        self.assertIn("WOULD REMOVE", out.getvalue())
        self.assertTrue(wt.exists())

    def test_duplicate_destination_is_rejected(self):
        wt = self.create()
        with self.assertRaises(ValueError):
            self.create()
        self.assertTrue(wt.exists())

    def test_invalid_name_or_missing_session_is_rejected(self):
        for name, session in [("../escape", "owner"), ("task", None)]:
            with self.assertRaises(ValueError):
                self.create(name, session)

    def test_subagent_and_invalid_events_are_ignored(self):
        wt = self.create()
        cleanup.event({"hook_event_name": "SessionEnd", "agent_id": "sub",
                       "session_id": "owner", "cwd": str(self.repo)})
        cleanup.event({"hook_event_name": "SessionEnd", "session_id": "owner"})
        self.assertTrue(wt.exists())

    def test_hook_cli_is_silent(self):
        result = subprocess.run(["python3", str(SCRIPT), "hook"], text=True,
                                input=json.dumps({"hook_event_name": "SessionStart",
                                                  "session_id": "test", "cwd": str(self.repo)}),
                                capture_output=True, check=True)
        self.assertEqual(result.stdout, "")
        self.assertEqual(result.stderr, "")


if __name__ == "__main__":
    unittest.main()
