#!/usr/bin/env bash
# session-cleanup.sh — se ejecuta al empezar y al terminar una sesión de Claude Code.
#
# Borra lo que los agentes generan y nunca recogen: clones temporales en el directorio
# temporal del sistema y worktrees de git huérfanos. Todo lo que NO se pueda borrar sin
# riesgo se deja en su sitio y se anota en el informe; nunca se pierde trabajo en silencio.
#
# Portable: macOS, Linux y Windows (Git Bash / WSL). No asume rutas absolutas ni GNU vs BSD.
#
# Reglas de seguridad (por qué no borra más de la cuenta):
#   1. Nada tocado en los últimos GRACE_MIN minutos  -> puede ser una sesión paralela viva.
#   2. Nada con cambios sin commitear                -> se anota y se conserva.
#   3. Nada con commits que no estén en su origen    -> se anota y se conserva.
#   4. Lista blanca intocable: sockets y estado vivo (docker, tmux, el puente del navegador,
#      y los scratchpads de Claude, que gestiona el propio harness).
#
# DRY_RUN=1 para ver qué haría sin borrar nada.

set -uo pipefail

GRACE_MIN=${GRACE_MIN:-60}
REPORT="${HOME}/.claude/session-cleanup-report.log"
DRY_RUN=${DRY_RUN:-0}

# Directorios que nunca se tocan, aunque cumplan el resto de reglas.
PROTEGIDOS='^(claude-[0-9]+|claude-.*|tmux-[0-9]+|docker-desktop-privileged.*|powerlog|\.X11-unix|systemd-.*)$'

log() { printf '%s\n' "$*" >> "$REPORT" 2>/dev/null; }
say() { [ "$DRY_RUN" = "1" ] && printf '%s\n' "$*"; }

borrar() {
  local ruta="$1" motivo="$2"
  if [ "$DRY_RUN" = "1" ]; then
    say "BORRARÍA  $ruta  ($motivo)"
  else
    rm -rf -- "$ruta" 2>/dev/null && log "  borrado: $ruta ($motivo)"
  fi
}

conservar() {
  local ruta="$1" motivo="$2"
  say "CONSERVO  $ruta  ($motivo)"
  log "  CONSERVADO: $ruta -> $motivo"
}

# ---------------------------------------------------------------------------
# Directorios temporales candidatos, según sistema operativo
# ---------------------------------------------------------------------------
# macOS: /private/tmp (y /tmp, que es un symlink al anterior)
# Linux: /tmp
# Windows (Git Bash): $TEMP / $TMP -> C:/Users/<u>/AppData/Local/Temp
raices_tmp() {
  local candidatos=()
  [ -n "${TMPDIR:-}" ] && candidatos+=("$TMPDIR")
  [ -n "${TEMP:-}" ]   && candidatos+=("$TEMP")
  [ -n "${TMP:-}" ]    && candidatos+=("$TMP")
  candidatos+=("/tmp" "/private/tmp")

  # Deduplicamos por ruta real: en macOS /tmp y /private/tmp son el mismo sitio.
  local vistos="" r real
  for r in "${candidatos[@]}"; do
    # En Git Bash, $TEMP/$TMP llegan en formato Windows (C:\Users\...\Temp).
    case "$r" in
      *\\*|[A-Za-z]:*)
        command -v cygpath >/dev/null 2>&1 && r=$(cygpath -u "$r" 2>/dev/null)
        ;;
    esac
    [ -d "$r" ] || continue
    real=$(cd "$r" 2>/dev/null && pwd -P) || continue
    case "|$vistos|" in
      *"|$real|"*) continue ;;
    esac
    vistos="$vistos|$real"
    printf '%s\n' "$real"
  done
}

# Edad en minutos, sin depender de `find -mmin` ni del formato de `stat`.
reciente() {
  local ruta="$1" edad
  # perl viene con macOS, con casi toda distro Linux y con Git for Windows.
  if command -v perl >/dev/null 2>&1; then
    edad=$(perl -e 'print int((time - (stat($ARGV[0]))[9]) / 60)' "$ruta" 2>/dev/null)
    if [ -n "$edad" ]; then
      [ "$edad" -lt "$GRACE_MIN" ]
      return $?
    fi
  fi
  # Sin perl: `find -mmin`, presente tanto en GNU find como en BSD find.
  [ -n "$(find "$ruta" -maxdepth 0 -mmin "-$GRACE_MIN" 2>/dev/null)" ]
}

log "=== $(date '+%Y-%m-%d %H:%M:%S') limpieza de sesión (cwd: ${CLAUDE_PROJECT_DIR:-$PWD}) ==="

# ---------------------------------------------------------------------------
# 1. Worktrees de git huérfanos en el proyecto actual
# ---------------------------------------------------------------------------
repo_raiz=$(git -C "${CLAUDE_PROJECT_DIR:-$PWD}" rev-parse --show-toplevel 2>/dev/null)
if [ -n "$repo_raiz" ]; then
  principal=$(git -C "$repo_raiz" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2; exit}')
  por_defecto=main
  git -C "$repo_raiz" rev-parse --verify main >/dev/null 2>&1 || por_defecto=master

  git -C "$repo_raiz" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2}' | while read -r wt; do
    [ "$wt" = "$principal" ] && continue
    [ -d "$wt" ] || continue

    sucio=$(git -C "$wt" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    if [ "$sucio" != "0" ]; then
      conservar "$wt" "$sucio ficheros sin commitear"
      continue
    fi

    cabeza=$(git -C "$wt" rev-parse HEAD 2>/dev/null)
    if ! git -C "$repo_raiz" merge-base --is-ancestor "$cabeza" "$por_defecto" 2>/dev/null; then
      sueltos=$(git -C "$repo_raiz" rev-list --count "$por_defecto".."$cabeza" 2>/dev/null)
      conservar "$wt" "$sueltos commits sin integrar en $por_defecto"
      continue
    fi

    if [ "$DRY_RUN" = "1" ]; then
      say "BORRARÍA  $wt  (worktree limpio y ya integrado en $por_defecto)"
    else
      git -C "$repo_raiz" worktree unlock "$wt" >/dev/null 2>&1
      git -C "$repo_raiz" worktree remove --force "$wt" >/dev/null 2>&1 \
        && log "  worktree eliminado: $wt (limpio y ya integrado)"
    fi
  done

  [ "$DRY_RUN" = "1" ] || git -C "$repo_raiz" worktree prune >/dev/null 2>&1
fi

# ---------------------------------------------------------------------------
# 2. Clones temporales en los directorios temporales del sistema
# ---------------------------------------------------------------------------
raices_tmp | while read -r raiz; do
  [ -d "$raiz" ] || continue
  say "--- escaneando $raiz ---"

  for ruta in "$raiz"/*; do
    [ -e "$ruta" ] || continue
    nombre=$(basename "$ruta")

    printf '%s' "$nombre" | grep -qE "$PROTEGIDOS" && continue

    # Sólo nos metemos con clones de git; ficheros sueltos y basura ajena se quedan.
    [ -e "$ruta/.git" ] || continue

    # Regla 1: si se ha tocado hace poco, otra sesión puede estar usándolo.
    if reciente "$ruta"; then
      conservar "$ruta" "modificado hace menos de $GRACE_MIN min (posible sesión viva)"
      continue
    fi

    sucio=$(git -C "$ruta" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    if [ "$sucio" != "0" ]; then
      conservar "$ruta" "$sucio ficheros sin commitear"
      continue
    fi

    # Regla 3: sus commits deben existir en el repo de origen.
    origen=$(git -C "$ruta" config --get remote.origin.url 2>/dev/null)
    cabeza=$(git -C "$ruta" rev-parse HEAD 2>/dev/null)
    if [ -n "$origen" ] && [ -d "$origen" ] && [ -n "$cabeza" ]; then
      if ! git -C "$origen" cat-file -e "$cabeza" 2>/dev/null; then
        conservar "$ruta" "tiene commits que no están en $origen"
        continue
      fi
    fi

    borrar "$ruta" "clone temporal obsoleto"
  done
done

log "=== fin ==="
exit 0
