WIP

My NVIM config is [here](https://github.com/aldezex/nvim) 🌚🐕

## Install

```sh
git clone https://github.com/aldezex/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh --dry-run   # ver qué haría
./install.sh
```

Enlaza cada fichero a su ruta en `$HOME`. Es idempotente, y todo lo que
sustituya se guarda antes en `~/.dotfiles-backup/<fecha>/`.

Como son symlinks, editar `~/.zshrc` es editar este repo: los cambios salen
en `git status` en vez de perderse. Para añadir un fichero nuevo, cópialo
aquí y mete su ruta en el array `LINKS` de `install.sh`.

| repo | destino |
|---|---|
| `zshrc` | `~/.zshrc` |
| `gitconfig` | `~/.gitconfig` |
| `githelpers` | `~/.githelpers` |
| `gitignore_global` | `~/.config/git/ignore` |
| `tmux.conf` | `~/.tmux.conf` |
| `ghostty.config` | `~/.config/ghostty/config` |
| `zed_settings.json` | `~/.config/zed/settings.json` |
| `zed_keymap.json` | `~/.config/zed/keymap.json` |
| `herdr.toml` | `~/.config/herdr/config.toml` |
| `herdr-hotkeys-cheatsheet.md` | `~/.config/herdr/hotkeys-cheatsheet.md` |
| `claude_settings.json` | `~/.claude/settings.json` |
| `claude_statusline.sh` | `~/.claude/statusline.sh` |
| `claude_hook_herdr-agent-state.sh` | `~/.claude/hooks/herdr-agent-state.sh` |

`claude_hook_herdr-agent-state.sh` lo gestiona herdr y lo sobrescribe al
actualizar la integración, así que puede aparecer modificado sin que lo hayas
tocado tú.
