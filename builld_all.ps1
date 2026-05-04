# Script de compilación multiplataforma para Folio
# Ver docs/RELEASES.md → sección FOLIO_DISTRIBUTION
param(
    # Carpeta de salida (por defecto [repo]/Output).
    [string] $Output = '',
    # Vacío = no añade --dart-define (comportamiento legado en Windows).
    [string] $DistributionWindowsGitHub = 'github',
    # Build MSIX / Partner Center (segundo build Windows).
    [string] $DistributionWindowsMicrosoftStore = 'microsoft_store',
    # Builds APK pensados para Google Play.
    [string] $DistributionAndroid = 'play_store',
    [string] $DistributionLinux = 'github',
    # Omitir segundo build Windows + MSIX (p. ej. sin certificado / solo GitHub).
    [switch] $SkipMicrosoftStore,
    # CI Windows no tiene Android SDK por defecto: usar en GitHub Actions y ejecutar APK en otro job.
    [switch] $SkipAndroid,
    # Solo en máquinas Linux/WSL; en Windows omitir o usar job ubuntu.
    [switch] $SkipLinux,
    # Origen de MS_STORE_* para --dart-define (por defecto functions/.env).
    [string] $MicrosoftStoreEnvFile = ''
)

$ErrorActionPreference = 'Stop'

$RepoRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Output)) {
    $OutputDir = Join-Path $RepoRoot 'Output'
} else {
    $OutputDir = $Output.Trim()
}

Write-Host "🚀 Iniciando proceso de compilación de Folio..." -ForegroundColor Cyan
Write-Host "📁 Salida: $OutputDir" -ForegroundColor Gray

# Devuelve $null o un string; el llamador debe usar Merge-FlutterDartDefines para no splatear un escalar.
function Get-FolioDistributionArg([string] $value) {
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $null
    }
    return '--dart-define=FOLIO_DISTRIBUTION=' + $value.Trim()
}

# Une argumentos extra a flutter sin el bug de PowerShell: @($string) splitea por caracteres.
function Merge-FlutterDartDefines([string[]] $BaseArgs, [object[]] $ExtraDefines) {
    $list = [System.Collections.Generic.List[string]]::new()
    foreach ($a in $BaseArgs) {
        if (-not [string]::IsNullOrWhiteSpace($a)) {
            $list.Add($a)
        }
    }
    foreach ($x in $ExtraDefines) {
        if ($null -eq $x) {
            continue
        }
        foreach ($part in @($x)) {
            if (-not [string]::IsNullOrWhiteSpace($part)) {
                $list.Add([string]$part)
            }
        }
    }
    return $list.ToArray()
}

# Lee líneas MS_STORE_* de functions/.env → --dart-define para el build Windows Store.
# (Azure AD va solo en el backend; no se pasa a Flutter.)
function Get-MicrosoftStoreDartDefinesFromEnv {
    param([string] $EnvFilePath)
    if ([string]::IsNullOrWhiteSpace($EnvFilePath)) {
        $EnvFilePath = Join-Path $RepoRoot 'functions\.env'
    }
    if (-not (Test-Path -LiteralPath $EnvFilePath)) {
        Write-Host "   (Sin $EnvFilePath : no se cargan MS_STORE_* para Flutter.)" -ForegroundColor DarkYellow
        return @()
    }
    $out = [System.Collections.Generic.List[string]]::new()
    foreach ($raw in Get-Content -LiteralPath $EnvFilePath) {
        $line = $raw.Trim()
        if ($line.Length -eq 0 -or $line.StartsWith('#')) {
            continue
        }
        $eq = $line.IndexOf('=')
        if ($eq -lt 1) {
            continue
        }
        $key = $line.Substring(0, $eq).Trim()
        if ($key -ne 'FOLIO_MS_STORE_LISTING_PRODUCT_ID' -and $key -notmatch '^MS_STORE_') {
            continue
        }
        $val = $line.Substring($eq + 1).Trim()
        if (($val.StartsWith('"') -and $val.EndsWith('"')) -or ($val.StartsWith("'") -and $val.EndsWith("'"))) {
            $val = $val.Substring(1, $val.Length - 2)
        }
        if ([string]::IsNullOrWhiteSpace($val)) {
            continue
        }
        $out.Add('--dart-define=' + $key + '=' + $val)
    }
    if ($out.Count -eq 0) {
        Write-Host "   (No hay claves MS_STORE_* en el .env ; añádelas en functions/.env)" -ForegroundColor DarkYellow
    } else {
        Write-Host "   → $($out.Count) dart-define(s) MS_STORE_* desde $(Split-Path $EnvFilePath -Leaf)" -ForegroundColor Gray
    }
    return $out.ToArray()
}

function Get-PubspecVersionRaw {
    $pubspec = Join-Path $RepoRoot 'pubspec.yaml'
    $line = Get-Content -LiteralPath $pubspec -ErrorAction Stop |
        Where-Object { $_ -match '^\s*version:\s*' } |
        Select-Object -First 1
    if (-not $line) { return '0.0.0+0' }
    return ($line -replace '^\s*version:\s*', '').Trim()
}

function Get-VersionForFileName([string] $raw) {
    if ([string]::IsNullOrWhiteSpace($raw)) { return '0-0-0' }
    return ($raw -replace '\+', '-')
}

function Ensure-OutputDir {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

function Assert-LastExitCode([string] $step) {
    if ($LASTEXITCODE -ne 0) {
        throw "Fallo en: $step (código de salida $LASTEXITCODE)."
    }
}

function Copy-WindowsReleaseZip {
    param(
        [string] $ZipBaseName
    )
    $release = Join-Path $RepoRoot 'build\windows\x64\runner\Release'
    if (-not (Test-Path -LiteralPath $release)) {
        Write-Warning "No se encontró $release ; se omite ZIP."
        return
    }
    $verSafe = Get-VersionForFileName (Get-PubspecVersionRaw)
    $zipPath = Join-Path $OutputDir "${ZipBaseName}-${verSafe}.zip"
    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }
    Compress-Archive -Path (Join-Path $release '*') -DestinationPath $zipPath -Force
    Write-Host "📦 ZIP: $zipPath" -ForegroundColor Green
}

function Copy-AndroidApk {
    $apk = Join-Path $RepoRoot 'build\app\outputs\flutter-apk\app-release.apk'
    if (-not (Test-Path -LiteralPath $apk)) {
        Write-Warning "No se encontró $apk ; se omite copia APK."
        return
    }
    $verSafe = Get-VersionForFileName (Get-PubspecVersionRaw)
    $dest = Join-Path $OutputDir "Folio-Android-PlayStore-${verSafe}.apk"
    Copy-Item -LiteralPath $apk -Destination $dest -Force
    Write-Host "📦 APK: $dest" -ForegroundColor Green
}

function Copy-MsixToOutput {
    $release = Join-Path $RepoRoot 'build\windows\x64\runner\Release'
    if (-not (Test-Path -LiteralPath $release)) {
        Write-Warning "No se encontró $release ; se omite MSIX."
        return
    }
    $msix = Get-ChildItem -LiteralPath $release -Filter '*.msix' -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if (-not $msix) {
        Write-Warning "No hay archivo .msix en Release ; ejecuta msix:create o revisa la salida del paquete."
        return
    }
    $verSafe = Get-VersionForFileName (Get-PubspecVersionRaw)
    $dest = Join-Path $OutputDir "Folio-MicrosoftStore-${verSafe}.msix"
    Copy-Item -LiteralPath $msix.FullName -Destination $dest -Force
    Write-Host "📦 MSIX: $dest" -ForegroundColor Green
}

function Copy-LinuxBundleZip {
    $bundle = Join-Path $RepoRoot 'build\linux\x64\release\bundle'
    if (-not (Test-Path -LiteralPath $bundle)) {
        Write-Warning "No se encontró $bundle ; se omite ZIP Linux."
        return
    }
    $verSafe = Get-VersionForFileName (Get-PubspecVersionRaw)
    $zipPath = Join-Path $OutputDir "Folio-Linux-GitHub-${verSafe}.zip"
    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }
    Compress-Archive -Path (Join-Path $bundle '*') -DestinationPath $zipPath -Force
    Write-Host "📦 ZIP Linux: $zipPath" -ForegroundColor Green
}

Set-Location -LiteralPath $RepoRoot
Ensure-OutputDir

# 1. Dependencias
Write-Host "`n📦 Obteniendo dependencias..." -ForegroundColor Yellow
flutter pub get
Assert-LastExitCode 'flutter pub get'

# 2. Windows (GitHub) → ZIP en Output
Write-Host "`n🪟 Compilando Windows (Release, canal GitHub)..." -ForegroundColor Cyan
$winGhArgs = Merge-FlutterDartDefines @('build', 'windows', '--release') @(
    (Get-FolioDistributionArg $DistributionWindowsGitHub)
)
& flutter @winGhArgs
Assert-LastExitCode 'flutter build windows (GitHub)'
Write-Host '✅ Windows (GitHub) listo.' -ForegroundColor Green
Copy-WindowsReleaseZip -ZipBaseName 'Folio-Windows-GitHub'

# 3. Windows (Microsoft Store) → MSIX en Output
if (-not $SkipMicrosoftStore) {
    Write-Host "`n🏪 Compilando Windows (Release, canal Microsoft Store) + MSIX..." -ForegroundColor Cyan
    $msEnv = if ([string]::IsNullOrWhiteSpace($MicrosoftStoreEnvFile)) {
        Join-Path $RepoRoot 'functions\.env'
    } else {
        $MicrosoftStoreEnvFile.Trim()
    }
    $winMsArgs = Merge-FlutterDartDefines @('build', 'windows', '--release') @(
        (Get-FolioDistributionArg $DistributionWindowsMicrosoftStore),
        (Get-MicrosoftStoreDartDefinesFromEnv -EnvFilePath $msEnv)
    )
    & flutter @winMsArgs
    Assert-LastExitCode 'flutter build windows (Microsoft Store)'
    Write-Host '✅ Windows (Microsoft Store) listo.' -ForegroundColor Green
    dart run msix:create
    Assert-LastExitCode 'dart run msix:create'
    Copy-MsixToOutput
} else {
    Write-Host "`n⏭️ Omitido: build Microsoft Store / MSIX (-SkipMicrosoftStore)." -ForegroundColor Magenta
}

# 4. Android (APK)
if (-not $SkipAndroid) {
    Write-Host "`n🤖 Compilando Android (APK Release)..." -ForegroundColor Cyan
    $apkArgs = Merge-FlutterDartDefines @('build', 'apk', '--release') @(
        (Get-FolioDistributionArg $DistributionAndroid)
    )
    & flutter @apkArgs
    Assert-LastExitCode 'flutter build apk'
    Write-Host '✅ Android listo.' -ForegroundColor Green
    Copy-AndroidApk
} else {
    Write-Host "`n⏭️ Omitido: Android (-SkipAndroid)." -ForegroundColor Magenta
}

# 5. Linux
if ($SkipLinux) {
    Write-Host "`n⏭️ Omitido: Linux (-SkipLinux)." -ForegroundColor Magenta
} elseif ($IsLinux -or $env:LSB_RELEASE -or $env:WSL_DISTRO_NAME) {
    Write-Host "`n🐧 Compilando Linux (Release)..." -ForegroundColor Cyan
    $linuxArgs = Merge-FlutterDartDefines @('build', 'linux', '--release') @(
        (Get-FolioDistributionArg $DistributionLinux)
    )
    & flutter @linuxArgs
    Assert-LastExitCode 'flutter build linux'
    Write-Host '✅ Linux listo.' -ForegroundColor Green
    Copy-LinuxBundleZip
} else {
    Write-Host "`n⚠️ Omitiendo Linux: no se detectó entorno Linux/WSL." -ForegroundColor Magenta
    Write-Host "Pista: para compilar Linux desde Windows, usa WSL (Ubuntu/Debian)." -ForegroundColor Gray
}

Write-Host "`n🎉 Proceso finalizado." -ForegroundColor Green
Write-Host "Artefactos recogidos en: $OutputDir" -ForegroundColor Gray
