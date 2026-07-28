# Instrucciones globales

## OBLIGATORIO: no dejes basura detrás

Regla de Álvaro (28-07-2026, tras quedarnos sin disco: 266 clones del repo mtgg abandonados
en `/private/tmp` ocupaban 268 GB, y ni un solo agente los recogió).

**Todo lo que generes fuera del repo es tuyo y lo recoges tú antes de terminar.** Esto incluye:

- **Clones y copias temporales** en el temporal del sistema — `/tmp` y `/private/tmp` en
  macOS, `/tmp` en Linux, `%TEMP%` en Windows — o en cualquier scratch. Si haces un
  `git clone` o `cp -r` del proyecto para probar algo, bórralo al acabar.
- **Worktrees de git.** Si creas uno, lo eliminas con `git worktree remove` cuando termines.
  Comprueba con `git worktree list` que no dejas ninguno de más.
- **Artefactos de build dentro de esas copias**: `node_modules`, `target`, `.next`, `dist`,
  `build`, `__pycache__`, `.venv`. En una copia temporal pesan 1-2 GB cada una.
- **Contenedores, imágenes y volúmenes de Docker** que hayas creado para una prueba puntual.

### Cómo hacerlo bien

1. **Trabaja dentro del proyecto siempre que puedas.** Un worktree en `.claude/worktrees/`
   es preferible a un clone suelto en `/tmp`: se ve en `git worktree list` y no se pierde.
2. **Si necesitas un scratch, usa el directorio de scratchpad de la sesión**, no `/private/tmp`
   a pelo. El harness lo aísla y lo etiqueta.
3. **Antes de dar una tarea por terminada**, comprueba y limpia:
   ```
   git worktree list                 # ¿queda alguno que hayas creado tú?
   ls "${TMPDIR:-/tmp}" /tmp         # ¿queda alguna copia tuya? (en Windows: ls "$TEMP")
   docker ps -a && docker images     # ¿queda algo de una prueba?
   ```
4. **Nunca borres a ciegas.** Antes de eliminar una copia o un worktree, verifica que no
   tiene cambios sin commitear ni commits que no estén en el repo de origen. Si los tiene,
   no lo borres: díselo a Álvaro.

### Red de seguridad

Hay un hook (`~/.claude/hooks/session-cleanup.sh`, registrado en `SessionStart` y
`SessionEnd`) que barre lo que se escape. **No es excusa para no limpiar**: es deliberadamente
conservador y sólo borra lo que puede probar que es desechable — respeta cualquier cosa
modificada en la última hora, con cambios sin commitear o con commits únicos. Todo lo que
decide conservar queda anotado en `~/.claude/session-cleanup-report.log`.
