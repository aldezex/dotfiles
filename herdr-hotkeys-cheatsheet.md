# herdr — keyboard shortcuts

Prefix: **Ctrl+Q** (was Ctrl+B by default; changed out of tmux habit, and tmux
is no longer installed).

The tmux equivalences below are kept as a mental map, not because tmux is still
around.

Real config in `~/.config/herdr/config.toml`. Reload with
`herdr server reload-config` after editing.

## Tabs (tmux "windows")
| Shortcut | Action |
|---|---|
| `prefix + c` | New tab |
| `prefix + Shift+T` | Rename tab |
| `prefix + e` (or `p`) | Previous tab |
| `prefix + Shift+E` (or `n`) | Next tab |
| `prefix + Shift+K` (or `Shift+X`) | Close tab |
| `prefix + 1..9` | Jump straight to tab N |

⚠️ There is no way to reorder or move tabs (neither by keyboard nor by mouse) —
it is not implemented in herdr.

## Panes / splits
| Shortcut | Action |
|---|---|
| `prefix + v` (or `prefix + Shift+_`) | Split right |
| `prefix + -` (minus) | Split down |
| `prefix + h/j/k/l` (or `Alt+←/↓/↑/→` without prefix) | Move between panes |
| `prefix + x` | Close pane |
| `prefix + z` | Zoom pane |
| `prefix + Shift+R` | Resize mode |
| `prefix + Shift+P` | Rename pane |
| `prefix + u` | Edit scrollback (used to be on `e`, moved) |

⚠️ There is no swap-pane (tmux's `>`/`<`) and no vi copy-mode — to copy, select
by dragging with the mouse.

## Spaces / workspaces (tmux "sessions")
| Shortcut | Action |
|---|---|
| `prefix + Shift+N` | New space |
| `prefix + Shift+W` | Rename space |
| `prefix + Shift+D` | Close space |
| `prefix + W` | Space picker |
| `prefix + G` | Goto / navigate mode (arrows do respond here) |
| `prefix + Shift+9` `(` | Previous space |
| `prefix + Shift+0` `)` | Next space |

## Agents (claude, codex, pi, opencode…)
They are not their own entity: they are an ordinary pane running the agent's
CLI, which herdr autodetects (working/blocked/done/idle in the sidebar).

| Shortcut | Action |
|---|---|
| `prefix + A` | Next agent |
| `prefix + Shift+A` | Previous agent |
| `prefix + Alt+1..9` | Jump straight to agent N |
| *(no dedicated shortcut)* | Open a new one: new split/tab, then type `claude`/`codex`/etc. |
| `prefix + Shift+P` | Rename (renames the pane holding it) |
| `prefix + x` | Close (kills the pane, and the process with it) |

## General
| Shortcut | Action |
|---|---|
| `prefix + r` | Reload config |
| `prefix + ?` | Show every active binding |
| `prefix + q` | Detach |
| Mouse | Still active in parallel (click, drag, resize) — nothing was disabled |
