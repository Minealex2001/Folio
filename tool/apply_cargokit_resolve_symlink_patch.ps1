# Copia el resolve_symlinks endurecido al paquete en pub cache y al symlink efímero
# de Windows. Ejecutar tras `flutter pub get` si CMake sigue mostrando el error
# de Get-Item en AppData.
$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$lockFile = Join-Path $repoRoot 'pubspec.lock'
if (-not (Test-Path $lockFile)) {
    Write-Error "No se encontró pubspec.lock en $repoRoot"
    exit 1
}

$ver = $null
$lines = Get-Content $lockFile
for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match '^\s+super_native_extensions:\s*$') {
        for ($j = $i + 1; $j -lt [Math]::Min($i + 25, $lines.Length); $j++) {
            if ($lines[$j] -match '^\s+version:\s*"([^"]+)"\s*$') {
                $ver = $Matches[1]
                break
            }
        }
        break
    }
}

if (-not $ver) {
    Write-Error 'No se pudo leer la versión de super_native_extensions en pubspec.lock'
    exit 1
}

$src = Join-Path $repoRoot 'tool\windows\cargokit_resolve_symlinks.ps1'
if (-not (Test-Path $src)) {
    Write-Error "Falta el script fuente: $src"
    exit 1
}

$cachePkg = Join-Path $env:LOCALAPPDATA "Pub\Cache\hosted\pub.dev\super_native_extensions-$ver"
$dstCache = Join-Path $cachePkg 'cargokit\cmake\resolve_symlinks.ps1'
if (Test-Path $dstCache) {
    Copy-Item -Path $src -Destination $dstCache -Force
    Write-Host "Actualizado: $dstCache"
} else {
    Write-Warning "No está el paquete en caché ($cachePkg). Ejecuta: flutter pub get"
}

$dstEphemeral = Join-Path $repoRoot 'windows\flutter\ephemeral\.plugin_symlinks\super_native_extensions\cargokit\cmake\resolve_symlinks.ps1'
if (Test-Path $dstEphemeral) {
    Copy-Item -Path $src -Destination $dstEphemeral -Force
    Write-Host "Actualizado: $dstEphemeral"
}
