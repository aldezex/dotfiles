#!/usr/bin/env bash
#
# Enlaza los ficheros de este repo a sus rutas en $HOME.
#
# Idempotente: se puede ejecutar tantas veces como haga falta. Todo lo que
# sustituya se guarda antes en ~/.dotfiles-backup/<fecha>/.
#
#   ./install.sh          instala
#   ./install.sh --dry-run   enseña qué haría, sin tocar nada

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
DRY_RUN=false

[ "${1:-}" = "--dry-run" ] && DRY_RUN=true

# origen (relativo al repo) -> destino (relativo a $HOME)
LINKS=(
    "zshrc:.zshrc"
    "gitconfig:.gitconfig"
    "githelpers:.githelpers"
    "gitignore_global:.config/git/ignore"
    "tmux.conf:.tmux.conf"
    "ghostty.config:.config/ghostty/config"
    "herdr.toml:.config/herdr/config.toml"
    "herdr-hotkeys-cheatsheet.md:.config/herdr/hotkeys-cheatsheet.md"
    "claude_settings.json:.claude/settings.json"
    "claude_statusline.sh:.claude/statusline.sh"
    "claude_hook_herdr-agent-state.sh:.claude/hooks/herdr-agent-state.sh"
)

backed_up=0
linked=0
skipped=0

say() { printf '%s\n' "$*"; }
run() { $DRY_RUN || "$@"; }

$DRY_RUN && say "── dry run: no se toca nada ──"

for entry in "${LINKS[@]}"; do
    src="$DOTFILES/${entry%%:*}"
    dest="$HOME/${entry##*:}"

    if [ ! -e "$src" ]; then
        say "!! falta en el repo, salto: ${entry%%:*}"
        continue
    fi

    # Ya enlazado a donde toca: nada que hacer.
    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
        skipped=$((skipped + 1))
        continue
    fi

    # Hay algo real ahí (o un symlink a otro sitio): guardarlo antes.
    # -e falla en symlinks rotos, por eso el -L.
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        run mkdir -p "$BACKUP_DIR/$(dirname "${entry##*:}")"
        run cp -R "$dest" "$BACKUP_DIR/${entry##*:}"
        run rm -rf "$dest"
        backed_up=$((backed_up + 1))
    fi

    run mkdir -p "$(dirname "$dest")"
    run ln -s "$src" "$dest"
    say "→ ${entry##*:}"
    linked=$((linked + 1))
done

say ""
say "enlazados: $linked   ya estaban: $skipped   guardados: $backed_up"
[ "$backed_up" -gt 0 ] && say "copia de seguridad en: $BACKUP_DIR"
exit 0
