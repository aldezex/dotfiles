#!/usr/bin/env python3
"""Apply a scoped dotfiles update, with backups and no dependency upgrades."""
import argparse
from copy import deepcopy
from datetime import datetime
import os
from pathlib import Path
import re
import shutil
import sys
try:
    import tomllib
except ImportError:
    raise SystemExit('Se necesita Python 3.11 o posterior; actualiza Python antes de continuar.')

REPO = Path(__file__).resolve().parents[1]
GROUPS = {
    'codex': ('codex_',),
    'claude': ('claude_',),
    'terminal': ('ghostty.config', 'herdr.toml', 'herdr-hotkeys-cheatsheet.md'),
    'shell': ('zshrc', 'zprofile', 'starship.toml', 'gitconfig', 'githelpers', 'gitignore_global'),
}
DEFAULTS = {
    '': {'model_verbosity': '"low"', 'tool_output_token_limit': '3000'},
    'features': {'hooks': 'true', 'remote_plugin': 'false', 'apps': 'false'},
    'mcp_servers.notion': {'enabled': 'false'},
}


def merge_defaults(text):
    """Change only the six managed scalar settings; verify semantic preservation."""
    before = tomllib.loads(text)
    expected = deepcopy(before)
    for section, values in DEFAULTS.items():
        table = expected
        for part in section.split('.') if section else []:
            table = table.setdefault(part, {})
        for key, literal in values.items():
            table[key] = tomllib.loads('v = ' + literal)['v']
        lines = text.splitlines(keepends=True)
        headers = [(i, line.strip().split('#', 1)[0].strip()) for i, line in enumerate(lines)
                   if line.lstrip().startswith('[')]
        if section:
            match = next((i for i, header in headers if header == '[' + section + ']'), None)
            if match is None:
                text += '\n[' + section + ']\n' + ''.join(k + ' = ' + v + '\n' for k, v in values.items())
                continue
            start = match + 1
        else:
            start = 0
        end = next((i for i, _ in headers if i >= start), len(lines))
        block = ''.join(lines[start:end])
        for key, literal in values.items():
            pattern = re.compile(r'^\s*' + re.escape(key) + r'\s*=.*$', re.M)
            replacement = key + ' = ' + literal
            if pattern.search(block):
                block = pattern.sub(lambda _: replacement, block, count=1)
            else:
                block = replacement + '\n' + block
        text = ''.join(lines[:start]) + block + ''.join(lines[end:])
    if tomllib.loads(text) != expected:
        raise ValueError('Formato TOML no compatible con la edición conservadora; configuración intacta.')
    return text


def planned_links(target):
    source = (REPO / 'setup-and-install.sh').read_text()
    block = source.split('LINKS=(', 1)[1].split('\n)', 1)[0]
    result = []
    for src, dest in re.findall(r'"([^":]+):([^"\n]+)"', block):
        if target == 'todo' or src.startswith(GROUPS[target]):
            result.append((src, dest))
    return result


def apply(target, home, dry_run=False):
    links = planned_links(target)
    for src, _ in links:
        if not (REPO / src).is_file():
            raise ValueError('Falta el archivo ' + src)
    config = home / '.codex/config.toml'
    new_config = None
    if target in ('codex', 'todo'):
        if config.is_symlink():
            raise ValueError('config.toml es un enlace: revisa su destino antes de actualizarlo.')
        if config.exists():
            original = config.read_text()
            merged = merge_defaults(original)
            if merged != original:
                new_config = merged
        else:
            new_config = (REPO / 'codex_config.toml').read_text()
        tomllib.loads(new_config if new_config is not None else config.read_text())
    changes = [(REPO / src, home / dest) for src, dest in links
               if not ((home / dest).is_symlink() and (home / dest).resolve() == (REPO / src).resolve())]
    for _, path in changes:
        if path.is_dir() and not path.is_symlink():
            raise ValueError('No se sustituye un directorio: ' + str(path))
    backup = home / '.dotfiles-backup' / ('actualiza-' + datetime.now().strftime('%Y%m%d-%H%M%S-%f'))

    def save(path):
        if path.exists() or path.is_symlink():
            dest = backup / path.relative_to(home)
            dest.parent.mkdir(parents=True, exist_ok=True)
            if path.is_symlink():
                # Preserve both link identity and the file's previous contents.
                dest.symlink_to(os.readlink(path))
                if path.is_file():
                    shutil.copy2(path, dest.with_name(dest.name + '.contents'))
            else:
                shutil.copy2(path, dest)

    for source, dest in changes:
        print(('WOULD LINK ' if dry_run else 'LINK ') + str(dest))
        if not dry_run:
            save(dest)
            dest.parent.mkdir(parents=True, exist_ok=True)
            pending = dest.with_name(dest.name + '.actualiza-' + str(os.getpid()))
            pending.symlink_to(source)
            pending.replace(dest)
    if new_config is not None:
        print(('WOULD UPDATE ' if dry_run else 'UPDATE ') + str(config))
        if not dry_run:
            save(config)
            config.parent.mkdir(parents=True, exist_ok=True)
            pending = config.with_name('config.toml.actualiza-' + str(os.getpid()))
            pending.write_text(new_config)
            pending.chmod(0o600)
            pending.replace(config)
    if not dry_run:
        # Merge ownership records; never prune links belonging to other targets.
        state_root = Path(os.environ.get('XDG_STATE_HOME', str(home / '.local/state')))
        state = state_root / 'dotfiles/linked'
        previous = state.read_text().splitlines() if state.exists() else []
        content = '\n'.join(dict.fromkeys(previous + [dest for _, dest in links])) + '\n'
        if not state.exists() or state.read_text() != content:
            state.parent.mkdir(parents=True, exist_ok=True)
            state.write_text(content)
    if backup.exists():
        print('BACKUP ' + str(backup))
    if not changes and new_config is None:
        print('Sin cambios: ya está actualizado.')
    if target in ('codex', 'todo'):
        print('Abre una sesión nueva de Codex y revisa /hooks si pide confiar en definiciones nuevas.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('target', choices=[*GROUPS, 'todo'])
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    if os.name != 'posix':
        parser.error('Ejecuta este comando en macOS, Linux o WSL.')
    if args.target in ('codex', 'todo') and os.environ.get('CODEX_HOME') and Path(os.environ['CODEX_HOME']).resolve() != (Path.home()/'.codex').resolve():
        parser.error('CODEX_HOME personalizado: este instalador gestiona ~/.codex. No se ha modificado nada.')
    try:
        apply(args.target, Path.home(), args.dry_run)
    except (OSError, ValueError, TypeError) as exc:
        parser.exit(1, 'Error: ' + str(exc) + '\n')


if __name__ == '__main__':
    main()
