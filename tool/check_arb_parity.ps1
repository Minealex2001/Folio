# Compara claves de localización entre los .arb de Folio.
# Uso: powershell -ExecutionPolicy Bypass -File tool/check_arb_parity.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$l10nDir = Join-Path $root 'lib\l10n'
$arbFiles = Get-ChildItem -Path $l10nDir -Filter 'app_*.arb' | Sort-Object Name

function Get-ArbKeys([string]$path) {
    $keys = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($line in Get-Content -Path $path) {
        if ($line -match '"([a-zA-Z][^"]*)"\s*:') {
            [void]$keys.Add($Matches[1])
        }
    }
    return $keys
}

$byFile = @{}
foreach ($f in $arbFiles) {
    $byFile[$f.Name] = Get-ArbKeys $f.FullName
}

$referenceName = 'app_en.arb'
if (-not $byFile.ContainsKey($referenceName)) {
    Write-Error "No se encontró $referenceName"
    exit 1
}
$reference = $byFile[$referenceName]
$failed = $false
foreach ($f in $arbFiles) {
    $keys = $byFile[$f.Name]
    $missing = $reference | Where-Object { -not $keys.Contains($_) }
    $extra = $keys | Where-Object { -not $reference.Contains($_) }
    if ($missing.Count -gt 0 -or $extra.Count -gt 0) {
        $failed = $true
        Write-Host "Desincronizado: $($f.Name)" -ForegroundColor Red
        if ($missing.Count -gt 0) {
            Write-Host "  Faltan ($($missing.Count)): $($missing | Select-Object -First 5 | ForEach-Object { $_ })" 
        }
        if ($extra.Count -gt 0) {
            Write-Host "  Sobran ($($extra.Count)): $($extra | Select-Object -First 5 | ForEach-Object { $_ })"
        }
    }
}

if ($failed) {
    Write-Host 'Paridad .arb: FALLO' -ForegroundColor Red
    exit 1
}

Write-Host "Paridad .arb: OK ($($arbFiles.Count) idiomas, $($reference.Count) claves)" -ForegroundColor Green
exit 0
