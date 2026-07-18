WIP

My NVIM config is [here](https://github.com/aldezex/nvim) 🌚🐕

## Install

macOS / Linux:

```sh
git clone https://github.com/aldezex/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh --dry-run   # ver qué haría
./install.sh
```

Windows (PowerShell):

```powershell
git clone https://github.com/aldezex/dotfiles.git $HOME\dotfiles
cd $HOME\dotfiles
.\install.ps1 -DryRun
.\install.ps1
```

Enlaza cada fichero a su ruta en `$HOME`. Es idempotente, y todo lo que
sustituya se guarda antes en `~/.dotfiles-backup/<fecha>/`.

Como son symlinks, editar `~/.zshrc` es editar este repo: los cambios salen
en `git status` en vez de perderse. Para añadir un fichero nuevo, cópialo
aquí y mete su ruta en el array `LINKS` (`.sh`) o `$Links` (`.ps1`).

En Windows los symlinks necesitan el Modo Desarrollador activado (Ajustes →
Sistema → Para programadores) o una consola de administrador. Si falla, el
script lo dice y sigue con el resto.

| repo | macOS / Linux | Windows |
|---|---|---|
| `zshrc` | `~/.zshrc` | — |
| `gitconfig` | `~/.gitconfig` | `~\.gitconfig` |
| `githelpers` | `~/.githelpers` | `~\.githelpers` |
| `gitignore_global` | `~/.config/git/ignore` | `~\.config\git\ignore` |
| `tmux.conf` | `~/.tmux.conf` | — |
| `ghostty.config` | `~/.config/ghostty/config` | — |
| `herdr.toml` | `~/.config/herdr/config.toml` | — |
| `herdr-hotkeys-cheatsheet.md` | `~/.config/herdr/hotkeys-cheatsheet.md` | — |
| `claude_settings.json` | `~/.claude/settings.json` | — |
| `claude_settings.windows.json` | — | `~\.claude\settings.json` |
| `claude_statusline.sh` | `~/.claude/statusline.sh` | — |
| `claude_statusline.ps1` | — | `~\.claude\statusline.ps1` |
| `claude_hook_herdr-agent-state.sh` | `~/.claude/hooks/herdr-agent-state.sh` | — |

Los `—` son cosas sin equivalente en ese sistema: no hay zsh ni tmux en
Windows, Ghostty no tiene build de Windows y herdr es macOS/Linux.

`claude_settings.windows.json` es el mismo fichero que la versión de macOS sin
el hook de herdr y apuntando al statusline `.ps1`. Si cambias un ajuste común
(modelo, tema, plugins), hay que tocarlo en los dos.

Los alias de git (`l`, `la`, `lr`, `ruf`) necesitan `sh`, `column` y `less`.
En Windows los trae Git for Windows.

`claude_hook_herdr-agent-state.sh` lo gestiona herdr y lo sobrescribe al
actualizar la integración, así que puede aparecer modificado sin que lo hayas
tocado tú.
