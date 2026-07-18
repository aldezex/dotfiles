# herdr — atajos de teclado (equivalentes a tmux)

Prefix: **Ctrl+Q** (antes Ctrl+B por defecto; cambiado para que coincida con tu `~/.tmux.conf`)

Config real en `~/.config/herdr/config.toml`. Recarga con `herdr server reload-config` tras editar.

## Tabs (= "windows" en tmux)
| Atajo | Acción |
|---|---|
| `prefix + c` | Nueva tab |
| `prefix + Shift+T` | Renombrar tab |
| `prefix + e`  (o `p`) | Tab anterior |
| `prefix + Shift+E`  (o `n`) | Tab siguiente |
| `prefix + Shift+K`  (o `Shift+X`) | Cerrar tab |
| `prefix + 1..9` | Saltar directo a la tab N |

⚠️ No existe forma de reordenar/mover tabs de sitio (ni por teclado ni por ratón) — no está implementado en herdr.

## Panes / splits
| Atajo | Acción |
|---|---|
| `prefix + v`  (o `prefix + Shift+_`) | Split a la derecha |
| `prefix + -` (minus) | Split abajo |
| `prefix + h/j/k/l`  (o `Alt+←/↓/↑/→` sin prefix) | Moverte entre panes |
| `prefix + x` | Cerrar pane |
| `prefix + z` | Zoom del pane |
| `prefix + Shift+R` | Modo resize |
| `prefix + Shift+P` | Renombrar pane |
| `prefix + u` | Editar scrollback (antes estaba en `e`, se movió) |

⚠️ No hay swap-pane (`>`/`<` de tmux) ni copy-mode vi — para copiar, seleccionar con arrastre de ratón.

## Spaces / Workspaces (= "sessions" en tmux)
| Atajo | Acción |
|---|---|
| `prefix + Shift+N` | Nuevo space |
| `prefix + Shift+W` | Renombrar space |
| `prefix + Shift+D` | Cerrar space |
| `prefix + W` | Selector de spaces (picker) |
| `prefix + G` | Goto / navigate mode (aquí sí responden las flechas ↑↓) |
| `prefix + Shift+9`  `(` | Space anterior |
| `prefix + Shift+0`  `)` | Space siguiente |

## Agentes (claude, codex, pi, opencode...)
No son una entidad propia: son un pane normal donde corres el CLI del agente y herdr lo autodetecta (estado working/blocked/done/idle en el sidebar).

| Atajo | Acción |
|---|---|
| `prefix + A` | Siguiente agente |
| `prefix + Shift+A` | Agente anterior |
| `prefix + Alt+1..9` | Saltar directo al agente N |
| *(sin atajo dedicado)* | Abrir uno nuevo: split/tab nueva + escribir `claude`/`codex`/etc. |
| `prefix + Shift+P` | Renombrar (renombra el pane que lo contiene) |
| `prefix + x` | Cerrar (mata el pane, y con él el proceso) |

## General
| Atajo | Acción |
|---|---|
| `prefix + r` | Reload config |
| `prefix + ?` | Ver todos los bindings activos |
| `prefix + q` | Detach |
| Ratón | Sigue activo en paralelo (clic, arrastre, resize) — no se desactivó nada |
