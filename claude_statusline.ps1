#!/usr/bin/env pwsh
#
# Port de claude_statusline.sh para Windows. Misma salida:
#   [Modelo] 📁 dir | 🌿 branch
#   ████░░░░░░ 42% | ⏱️ 1m 35s
#
# Claude Code manda el JSON de estado por stdin.

$ErrorActionPreference = 'Stop'

$raw = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }

try { $data = $raw | ConvertFrom-Json } catch { exit 0 }

function Get-Or($value, $fallback) {
    if ($null -eq $value) { return $fallback }
    return $value
}

$model = Get-Or $data.model.display_name 'claude'
$dir   = Get-Or $data.workspace.current_dir (Get-Location).Path
$pct   = [int][math]::Floor([double](Get-Or $data.context_window.used_percentage 0))
$durMs = [double](Get-Or $data.cost.total_duration_ms 0)

$e = [char]27
$cyan = "$e[36m"; $green = "$e[32m"; $yellow = "$e[33m"; $red = "$e[31m"; $reset = "$e[0m"

# Color de la barra según cuánto contexto se ha gastado.
if     ($pct -ge 90) { $barColor = $red }
elseif ($pct -ge 70) { $barColor = $yellow }
else                 { $barColor = $green }

$filled = [math]::Floor($pct / 10)
$empty  = 10 - $filled
$bar    = ('█' * $filled) + ('░' * $empty)

$mins = [math]::Floor($durMs / 60000)
$secs = [math]::Floor(($durMs % 60000) / 1000)

# La rama solo si estamos dentro de un repo; si no, se omite igual que en el .sh
$branch = ''
git rev-parse --git-dir *> $null
if ($LASTEXITCODE -eq 0) {
    $name = (git branch --show-current 2>$null)
    if (-not [string]::IsNullOrWhiteSpace($name)) { $branch = " | 🌿 $name" }
}

$leaf = Split-Path -Leaf $dir

Write-Output "$cyan[$model]$reset 📁 $leaf$branch"
Write-Output "$barColor$bar$reset $pct% | ⏱️ ${mins}m ${secs}s"
