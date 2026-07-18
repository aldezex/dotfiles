#!/usr/bin/env pwsh
#
# Equivalente de install.sh para Windows.
#
# Idempotente: se puede ejecutar tantas veces como haga falta. Todo lo que
# sustituya se guarda antes en ~\.dotfiles-backup\<fecha>\.
#
#   .\install.ps1            instala
#   .\install.ps1 -DryRun    enseña qué haría, sin tocar nada
#
# Los symlinks en Windows necesitan Modo Desarrollador activado (Ajustes ->
# Sistema -> Para programadores) o una consola de administrador. Si no, el
# script avisa y sigue con el resto en vez de abortar.

[CmdletBinding()]
param([switch]$DryRun)

$ErrorActionPreference = 'Stop'

$Dotfiles  = $PSScriptRoot
$Home_     = $HOME
$BackupDir = Join-Path $Home_ ".dotfiles-backup\$(Get-Date -Format 'yyyyMMdd-HHmmss')"

# origen (relativo al repo) -> destino (relativo a $HOME)
$Links = [ordered]@{
    'gitconfig'                    = '.gitconfig'
    'githelpers'                   = '.githelpers'
    'gitignore_global'             = '.config\git\ignore'
    'claude_settings.windows.json' = '.claude\settings.json'
    'claude_statusline.ps1'        = '.claude\statusline.ps1'
}

# Sin equivalente en Windows. Se listan al final para que quede claro que es
# a propósito y no un olvido.
$NotApplicable = [ordered]@{
    'zshrc'                            = 'no hay zsh; en Windows se usa PowerShell'
    'tmux.conf'                        = 'tmux no es nativo de Windows'
    'ghostty.config'                   = 'Ghostty no tiene build de Windows'
    'herdr.toml'                       = 'herdr es macOS/Linux'
    'herdr-hotkeys-cheatsheet.md'      = 'idem'
    'claude_hook_herdr-agent-state.sh' = 'depende de herdr'
}

$linked = 0; $skipped = 0; $backedUp = 0; $failed = 0

if ($DryRun) { Write-Host '── dry run: no se toca nada ──' }

foreach ($entry in $Links.GetEnumerator()) {
    $src  = Join-Path $Dotfiles $entry.Key
    $dest = Join-Path $Home_ $entry.Value

    if (-not (Test-Path -LiteralPath $src)) {
        Write-Host "!! falta en el repo, salto: $($entry.Key)"
        continue
    }

    # Ya enlazado a donde toca: nada que hacer.
    $existing = Get-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue
    if ($existing -and $existing.LinkType -eq 'SymbolicLink' -and $existing.Target -eq $src) {
        $skipped++
        continue
    }

    # Hay algo real ahí (o un symlink a otro sitio): guardarlo antes, pero sin
    # borrar el original todavía — si el symlink falla más abajo, se queda
    # donde estaba en vez de perderse.
    $backupPath = $null
    if ($existing) {
        if (-not $DryRun) {
            $backupPath = Join-Path $BackupDir $entry.Value
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $backupPath) | Out-Null
            Copy-Item -LiteralPath $dest -Destination $backupPath -Recurse -Force
        }
        $backedUp++
    }

    if (-not $DryRun) {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
        if ($existing) { Remove-Item -LiteralPath $dest -Recurse -Force }
        try {
            New-Item -ItemType SymbolicLink -Path $dest -Target $src -Force | Out-Null
        } catch {
            Write-Host "!! no se pudo enlazar $($entry.Value): $($_.Exception.Message)"
            if ($backupPath) {
                Copy-Item -LiteralPath $backupPath -Destination $dest -Recurse -Force
                Write-Host "   restaurado desde el backup, sin cambios netos"
            }
            $failed++
            continue
        }
    }

    Write-Host "→ $($entry.Value)"
    $linked++
}

Write-Host ''
Write-Host "enlazados: $linked   ya estaban: $skipped   guardados: $backedUp"
if ($backedUp -gt 0 -and -not $DryRun) { Write-Host "copia de seguridad en: $BackupDir" }

if ($failed -gt 0) {
    Write-Host ''
    Write-Host "$failed enlace(s) fallaron. Casi siempre es permisos:"
    Write-Host 'activa el Modo Desarrollador (Ajustes -> Sistema -> Para programadores)'
    Write-Host 'o ejecuta esto desde una consola de administrador, y repite.'
}

Write-Host ''
Write-Host 'omitidos (sin equivalente en Windows):'
foreach ($na in $NotApplicable.GetEnumerator()) {
    Write-Host "  $($na.Key) — $($na.Value)"
}
