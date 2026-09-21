import contextlib
import importlib.util
import io
import os
from pathlib import Path
import tempfile
import tomllib
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/actualiza.py'
spec = importlib.util.spec_from_file_location('actualiza', SCRIPT)
a = importlib.util.module_from_spec(spec)
spec.loader.exec_module(a)


class UpdateTests(unittest.TestCase):
    def test_preserves_unrelated_config_and_comments(self):
        text = '# Personal settings\nmodel = "custom"\nmodel_reasoning_effort = "high"\n[projects."/home/me/work"]\ntrust_level="trusted"\n[features]\napps=true\nother=true\n[mcp_servers.notion]\nurl="https://example.invalid"\n'
        merged = a.merge_defaults(text)
        parsed = tomllib.loads(merged)
        self.assertEqual(parsed['model'], 'custom')
        self.assertEqual(parsed['model_reasoning_effort'], 'high')
        self.assertEqual(parsed['projects']['/home/me/work']['trust_level'], 'trusted')
        self.assertTrue(parsed['features']['other'])
        self.assertFalse(parsed['features']['apps'])
        self.assertEqual(parsed['mcp_servers']['notion']['url'], 'https://example.invalid')
        self.assertIn('# Personal settings', merged)
        self.assertEqual(a.merge_defaults(merged), merged)

    def test_unusual_layout_rejected(self):
        with self.assertRaises(ValueError):
            a.merge_defaults('features = { apps = true }\n')

    def test_target_selection(self):
        self.assertTrue(a.planned_links('codex'))
        self.assertTrue(all(src.startswith('codex_') for src, _ in a.planned_links('codex')))
        self.assertFalse(any(src.startswith('claude_') for src, _ in a.planned_links('codex')))

    def test_backup_dry_run_and_second_run(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            config = home / '.codex/config.toml'
            config.parent.mkdir()
            config.write_text('model="my-model"\n')
            agents = home / '.codex/AGENTS.md'
            agents.write_text('old instructions')
            with patch.dict(os.environ, {'XDG_STATE_HOME': str(home / 'state')}):
                with contextlib.redirect_stdout(io.StringIO()):
                    a.apply('codex', home, True)
                self.assertEqual(config.read_text(), 'model="my-model"\n')
                self.assertFalse((home / '.dotfiles-backup').exists())
                with contextlib.redirect_stdout(io.StringIO()):
                    a.apply('codex', home)
                self.assertTrue(agents.is_symlink())
                backups = list((home / '.dotfiles-backup').glob('actualiza-*'))
                self.assertEqual(len(backups), 1)
                self.assertEqual((backups[0] / '.codex/AGENTS.md').read_text(), 'old instructions')
                self.assertEqual((backups[0] / '.codex/config.toml').read_text(), 'model="my-model"\n')
                before = config.stat().st_mtime_ns
                with contextlib.redirect_stdout(io.StringIO()) as output:
                    a.apply('codex', home)
                self.assertIn('Sin cambios', output.getvalue())
                self.assertEqual(config.stat().st_mtime_ns, before)
                self.assertEqual(len(list((home / '.dotfiles-backup').glob('actualiza-*'))), 1)


if __name__ == '__main__':
    unittest.main()
