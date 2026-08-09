# Script de compilacion y publicacion multiplataforma para Folio
# Ver docs/RELEASES.md
#
# Uso (solo menus interactivos):
#   .\builld_all.ps1
#
# Elige en pantalla: publicar estable/beta, alcance global o por plataforma,
# compilar localmente, etc. No hace falta pasar parametros.
#
# Tags: vX.Y.Z (global) o vX.Y.Z-android|windows|linux|macos
# CI (GitHub Actions) puede seguir invocando con parametros internos; uso humano = menu.
param(
    # Uso interno / CI. Dejar vacio → menu interactivo.
    [ValidateSet('', 'menu', 'build-all', 'release', 'prerelease', 'installer', 'windows', 'store', 'android', 'linux', 'macos', 'notes', 'clean')]
    [string] $Action = '',
    [string] $Output = '',
    [string] $DistributionWindowsGitHub = 'github',
    [string] $DistributionWindowsMicrosoftStore = 'microsoft_store',
    [string] $DistributionAndroid = 'play_store',
    [string] $DistributionLinux = 'github',
    [string] $DistributionMacOS = 'github',
    [switch] $SkipMicrosoftStore,
    [switch] $SkipAndroid,
    [switch] $SkipLinux,
    [switch] $SkipMacOS,
    [string] $MicrosoftStoreEnvFile = '',
    [switch] $Clean,
    [switch] $NonInteractive,
    [string] $ReleaseTag = '',
    [string] $ReleaseTarget = '',
    [switch] $PreRelease,
    [switch] $DraftRelease,
    [string] $BumpVersion = '',
    [string] $ReleaseNotes = '',
    [string] $ReleaseNotesFile = '',
    [string] $FolioWebBaseUrl = '',
    [string] $FolioBackendBaseUrl = '',
    [ValidateSet('global', 'android', 'windows', 'linux', 'macos')]
    [string] $PlatformScope = 'global',
    [switch] $Yes
)

$ErrorActionPreference = 'Stop'

$RepoRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Output)) {
    $OutputDir = Join-Path $RepoRoot 'Output'
} else {
    $OutputDir = $Output.Trim()
}

# Canal de enlaces web embebidos en el binario (production | beta | '').
# Lo fija Invoke-PublishFlow; build local sin publicar deja el default del codigo.
$script:FolioWebChannel = ''
# Si el menu global desmarca Windows, no se compila instalador/ZIP Windows.
$script:FolioPublishSkipWindows = $false

# ---------------------------------------------------------------------------
# Utilidades comunes
# ---------------------------------------------------------------------------

# Devuelve $null o un string; el llamador debe usar Merge-FlutterDartDefines para no splatear un escalar.
function Get-FolioDistributionArg([string] $value) {
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $null
    }
    return '--dart-define=FOLIO_DISTRIBUTION=' + $value.Trim()
}

# Enlaces de usuario (compartir libreta, reset/verify). Desktop/móvil no tienen Uri.base de la web.
function Get-FolioWebBaseUrlArg {
    if (-not [string]::IsNullOrWhiteSpace($FolioWebBaseUrl)) {
        $base = $FolioWebBaseUrl.Trim().TrimEnd('/')
        Write-Host "   -> FOLIO_WEB_BASE_URL=$base (override -FolioWebBaseUrl)" -ForegroundColor Gray
        return "--dart-define=FOLIO_WEB_BASE_URL=$base"
    }
    switch ($script:FolioWebChannel) {
        'beta' {
            $base = 'https://foliobeta.minealexgames.com'
            Write-Host "   -> FOLIO_WEB_BASE_URL=$base (canal Beta / prerelease)" -ForegroundColor Gray
            return "--dart-define=FOLIO_WEB_BASE_URL=$base"
        }
        'production' {
            $base = 'https://folio.minealexgames.com'
            Write-Host "   -> FOLIO_WEB_BASE_URL=$base (canal estable / release)" -ForegroundColor Gray
            return "--dart-define=FOLIO_WEB_BASE_URL=$base"
        }
        default {
            return $null
        }
    }
}

# Backend Spring (API). Mismo canal que Get-FolioWebBaseUrlArg: beta para
# prerelease, produccion para release estable. Sin -AsPreRelease/-AsRelease
# (build local suelto, sin publicar) deja el default compilado en
# folio_local_secrets.dart (= beta).
function Get-FolioBackendBaseUrlArg {
    if (-not [string]::IsNullOrWhiteSpace($FolioBackendBaseUrl)) {
        $base = $FolioBackendBaseUrl.Trim().TrimEnd('/')
        Write-Host "   -> FOLIO_BACKEND_BASE_URL=$base (override -FolioBackendBaseUrl)" -ForegroundColor Gray
        return "--dart-define=FOLIO_BACKEND_BASE_URL=$base"
    }
    switch ($script:FolioWebChannel) {
        'beta' {
            # Solo beta usa api-beta.folio.com.es (bypass filtros que categorizan minealexgames).
            $base = 'https://api-beta.folio.com.es'
            Write-Host "   -> FOLIO_BACKEND_BASE_URL=$base (canal Beta / prerelease)" -ForegroundColor Gray
            return "--dart-define=FOLIO_BACKEND_BASE_URL=$base"
        }
        'production' {
            $base = 'https://backendfolio.minealexgames.com'
            Write-Host "   -> FOLIO_BACKEND_BASE_URL=$base (canal estable / release)" -ForegroundColor Gray
            return "--dart-define=FOLIO_BACKEND_BASE_URL=$base"
        }
        default {
            return $null
        }
    }
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

# Lee lineas MS_STORE_* de functions/.env -> --dart-define para el build Windows Store.
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
        Write-Host "   (No hay claves MS_STORE_* en el .env ; anadelas en functions/.env)" -ForegroundColor DarkYellow
    } else {
        Write-Host "   -> $($out.Count) dart-define(s) MS_STORE_* desde $(Split-Path $EnvFilePath -Leaf)" -ForegroundColor Gray
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

# semver sin el sufijo +build (para tags y nombre de instalador).
function Get-PubspecSemver {
    $raw = Get-PubspecVersionRaw
    return $raw.Split('+')[0].Trim()
}

function Get-VersionForFileName([string] $raw) {
    if ([string]::IsNullOrWhiteSpace($raw)) { return '0-0-0' }
    return ($raw -replace '\+', '-')
}

# Reescribe la linea version: de pubspec.yaml.
function Set-PubspecVersion([string] $newVersion) {
    if ([string]::IsNullOrWhiteSpace($newVersion)) { return }
    $newVersion = $newVersion.Trim()
    if ($newVersion -notmatch '^\d+\.\d+\.\d+(\+\d+)?$') {
        throw "Version invalida: '$newVersion'. Usa el formato X.Y.Z o X.Y.Z+build."
    }
    $pubspec = Join-Path $RepoRoot 'pubspec.yaml'
    $content = Get-Content -LiteralPath $pubspec
    $replaced = $false
    $content = $content | ForEach-Object {
        if (-not $replaced -and $_ -match '^\s*version:\s*') {
            $replaced = $true
            "version: $newVersion"
        } else {
            $_
        }
    }
    if (-not $replaced) {
        throw "No se encontro la linea 'version:' en pubspec.yaml."
    }
    Set-Content -LiteralPath $pubspec -Value $content -Encoding utf8
    Write-Host "pubspec.yaml -> version: $newVersion" -ForegroundColor Green
}

function Ensure-OutputDir {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

function Assert-LastExitCode([string] $step) {
    if ($LASTEXITCODE -ne 0) {
        throw "Fallo en: $step (codigo de salida $LASTEXITCODE)."
    }
}

function Invoke-FlutterClean {
    Write-Host "`n[clean] Ejecutando flutter clean..." -ForegroundColor Yellow
    & flutter clean
    Assert-LastExitCode 'flutter clean'
    Write-Host 'Limpieza completada.' -ForegroundColor Green
}

function Invoke-FlutterPubGet {
    Write-Host "`n[deps] Obteniendo dependencias..." -ForegroundColor Yellow
    & flutter pub get
    Assert-LastExitCode 'flutter pub get'
}

# ---------------------------------------------------------------------------
# Copia de artefactos a Output
# ---------------------------------------------------------------------------

function Copy-WindowsReleaseZip {
    param(
        [string] $ZipBaseName
    )
    $release = Join-Path $RepoRoot 'build\windows\x64\runner\Release'
    if (-not (Test-Path -LiteralPath $release)) {
        Write-Warning "No se encontro $release ; se omite ZIP."
        return
    }
    $verSafe = Get-VersionForFileName (Get-PubspecVersionRaw)
    $zipPath = Join-Path $OutputDir "${ZipBaseName}-${verSafe}.zip"
    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }
    Compress-Archive -Path (Join-Path $release '*') -DestinationPath $zipPath -Force
    Write-Host "[ok] ZIP: $zipPath" -ForegroundColor Green
}

function Copy-AndroidApk {
    $apk = Join-Path $RepoRoot 'build\app\outputs\flutter-apk\app-release.apk'
    if (-not (Test-Path -LiteralPath $apk)) {
        Write-Warning "No se encontro $apk ; se omite copia APK."
        return
    }
    $verSafe = Get-VersionForFileName (Get-PubspecVersionRaw)
    $dest = Join-Path $OutputDir "Folio-Android-PlayStore-${verSafe}.apk"
    Copy-Item -LiteralPath $apk -Destination $dest -Force
    Write-Host "[ok] APK: $dest" -ForegroundColor Green
}

function Copy-AndroidAab {
    $aab = Join-Path $RepoRoot 'build\app\outputs\bundle\release\app-release.aab'
    if (-not (Test-Path -LiteralPath $aab)) {
        Write-Warning "No se encontro $aab ; se omite copia AAB."
        return
    }
    $verSafe = Get-VersionForFileName (Get-PubspecVersionRaw)
    $dest = Join-Path $OutputDir "Folio-Android-PlayStore-${verSafe}.aab"
    Copy-Item -LiteralPath $aab -Destination $dest -Force
    Write-Host "[ok] AAB: $dest" -ForegroundColor Green
}

function Copy-MsixToOutput {
    $release = Join-Path $RepoRoot 'build\windows\x64\runner\Release'
    if (-not (Test-Path -LiteralPath $release)) {
        Write-Warning "No se encontro $release ; se omite MSIX."
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
    Write-Host "[ok] MSIX: $dest" -ForegroundColor Green
}

function Copy-LinuxBundleZip {
    $bundle = Join-Path $RepoRoot 'build\linux\x64\release\bundle'
    if (-not (Test-Path -LiteralPath $bundle)) {
        Write-Warning "No se encontro $bundle ; se omite ZIP Linux."
        return
    }
    $verSafe = Get-VersionForFileName (Get-PubspecVersionRaw)
    $zipPath = Join-Path $OutputDir "Folio-Linux-GitHub-${verSafe}.zip"
    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }
    Compress-Archive -Path (Join-Path $bundle '*') -DestinationPath $zipPath -Force
    Write-Host "[ok] ZIP Linux: $zipPath" -ForegroundColor Green
}

function Copy-MacOSAppZip {
    $products = Join-Path $RepoRoot 'build\macos\Build\Products\Release'
    if (-not (Test-Path -LiteralPath $products)) {
        Write-Warning "No se encontro $products ; se omite ZIP macOS."
        return
    }
    $app = Get-ChildItem -LiteralPath $products -Filter '*.app' -Directory -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $app) {
        Write-Warning "No hay .app en $products ; se omite ZIP macOS."
        return
    }
    $verSafe = Get-VersionForFileName (Get-PubspecVersionRaw)
    $zipPath = Join-Path $OutputDir "Folio-macOS-GitHub-${verSafe}.zip"
    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }
    Compress-Archive -Path $app.FullName -DestinationPath $zipPath -Force
    Write-Host "[ok] ZIP macOS: $zipPath" -ForegroundColor Green
}

# Artefactos conocidos en Output/ para adjuntar a una release de GitHub
# (solo la version actual de pubspec, para no subir restos de builds anteriores).
function Get-OutputReleaseAssets {
    if (-not (Test-Path -LiteralPath $OutputDir)) {
        return @()
    }
    $verSafe = Get-VersionForFileName (Get-PubspecVersionRaw)
    $semver = Get-PubspecSemver
    $patterns = @(
        "Folio-Setup-$semver.exe",
        "Folio-Windows-GitHub-$verSafe.zip",
        "Folio-MicrosoftStore-$verSafe.msix",
        "Folio-Android-PlayStore-$verSafe.apk",
        "Folio-Android-PlayStore-$verSafe.aab",
        "Folio-Linux-GitHub-$verSafe.zip",
        "Folio-macOS-GitHub-$verSafe.zip"
    )
    $files = [System.Collections.Generic.List[string]]::new()
    foreach ($name in $patterns) {
        $path = Join-Path $OutputDir $name
        if (Test-Path -LiteralPath $path) {
            $files.Add($path)
        }
    }
    return $files.ToArray()
}

function Test-IsLinuxHost {
    if ($IsLinux) { return $true }
    if ($env:WSL_DISTRO_NAME) { return $true }
    if ($env:LSB_RELEASE) { return $true }
    return $false
}

function Test-IsMacOSHost {
    if ($IsMacOS) { return $true }
    if ($env:OSTYPE -match 'darwin') { return $true }
    return $false
}

function Test-WslAvailable {
    $wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
    if (-not $wsl) { return $false }
    & wsl.exe -e true *> $null
    return ($LASTEXITCODE -eq 0)
}

# E:\Repos\Folio -> /mnt/e/Repos/Folio
function ConvertTo-WslPath([string] $windowsPath) {
    $resolved = $windowsPath
    try {
        $resolved = (Resolve-Path -LiteralPath $windowsPath).Path
    } catch {
        # usar tal cual
    }
    if ($resolved -match '^([A-Za-z]):\\(.*)$') {
        $drive = $Matches[1].ToLower()
        $rest = ($Matches[2] -replace '\\', '/')
        return "/mnt/$drive/$rest"
    }
    return ($resolved -replace '\\', '/')
}

# ---------------------------------------------------------------------------
# Builds por plataforma
# ---------------------------------------------------------------------------

function Build-WindowsGitHub {
    Write-Host "`n[win] Compilando Windows (Release, canal GitHub)..." -ForegroundColor Cyan
    $winGhArgs = Merge-FlutterDartDefines @('build', 'windows', '--release') @(
        (Get-FolioDistributionArg $DistributionWindowsGitHub),
        (Get-FolioWebBaseUrlArg),
        (Get-FolioBackendBaseUrlArg)
    )
    & flutter @winGhArgs
    Assert-LastExitCode 'flutter build windows (GitHub)'
    Write-Host 'Windows (GitHub) listo.' -ForegroundColor Green
    Copy-WindowsReleaseZip -ZipBaseName 'Folio-Windows-GitHub'
}

function Build-WindowsStore {
    Write-Host "`n[store] Compilando Windows (Release, canal Microsoft Store) + MSIX..." -ForegroundColor Cyan
    $msEnv = if ([string]::IsNullOrWhiteSpace($MicrosoftStoreEnvFile)) {
        Join-Path $RepoRoot 'functions\.env'
    } else {
        $MicrosoftStoreEnvFile.Trim()
    }
    $winMsArgs = Merge-FlutterDartDefines @('build', 'windows', '--release') @(
        (Get-FolioDistributionArg $DistributionWindowsMicrosoftStore),
        (Get-MicrosoftStoreDartDefinesFromEnv -EnvFilePath $msEnv),
        (Get-FolioWebBaseUrlArg),
        (Get-FolioBackendBaseUrlArg)
    )
    & flutter @winMsArgs
    Assert-LastExitCode 'flutter build windows (Microsoft Store)'
    Write-Host 'Windows (Microsoft Store) listo.' -ForegroundColor Green
    # La Store exige nombres de paquete unicos: la version del MSIX debe subir en cada
    # publicacion. Se sincroniza con pubspec.yaml (semver) + segmento revision 0.
    $msixVersion = (Get-PubspecSemver) + '.0'
    Write-Host "MSIX version: $msixVersion (desde pubspec.yaml)" -ForegroundColor Gray
    & dart run msix:create --store --version $msixVersion
    Assert-LastExitCode 'dart run msix:create'
    Copy-MsixToOutput
}

function Build-Android {
    Write-Host "`n[android] Compilando Android (APK Release)..." -ForegroundColor Cyan
    $apkArgs = Merge-FlutterDartDefines @('build', 'apk', '--release') @(
        (Get-FolioDistributionArg $DistributionAndroid),
        (Get-FolioWebBaseUrlArg),
        (Get-FolioBackendBaseUrlArg)
    )
    & flutter @apkArgs
    Assert-LastExitCode 'flutter build apk'
    Write-Host 'Android APK listo.' -ForegroundColor Green
    Copy-AndroidApk

    Write-Host "`n[android] Compilando Android (AAB Release)..." -ForegroundColor Cyan
    $aabArgs = Merge-FlutterDartDefines @('build', 'appbundle', '--release') @(
        (Get-FolioDistributionArg $DistributionAndroid),
        (Get-FolioWebBaseUrlArg),
        (Get-FolioBackendBaseUrlArg)
    )
    & flutter @aabArgs
    Assert-LastExitCode 'flutter build appbundle'
    Write-Host 'Android AAB listo.' -ForegroundColor Green
    Copy-AndroidAab
}

function Build-LinuxNative {
    Write-Host "`n[linux] Compilando Linux nativo (Release)..." -ForegroundColor Cyan
    $linuxArgs = Merge-FlutterDartDefines @('build', 'linux', '--release') @(
        (Get-FolioDistributionArg $DistributionLinux),
        (Get-FolioWebBaseUrlArg),
        (Get-FolioBackendBaseUrlArg)
    )
    & flutter @linuxArgs
    Assert-LastExitCode 'flutter build linux'
    Write-Host 'Linux listo.' -ForegroundColor Green
    Copy-LinuxBundleZip
}

# Compila Linux dentro de WSL (Flutter + deps GTK deben estar instalados en la distro).
function Build-LinuxViaWsl {
    Write-Host "`n[linux] Compilando Linux via WSL (Release)..." -ForegroundColor Cyan
    $wslRoot = ConvertTo-WslPath $RepoRoot
    $wslOut = ConvertTo-WslPath $OutputDir
    $distDefine = ''
    if (-not [string]::IsNullOrWhiteSpace($DistributionLinux)) {
        $distDefine = "--dart-define=FOLIO_DISTRIBUTION=$($DistributionLinux.Trim())"
    }
    $webDefine = ''
    $webArg = Get-FolioWebBaseUrlArg
    if (-not [string]::IsNullOrWhiteSpace($webArg)) {
        $webDefine = [string]$webArg
    }
    $backendDefine = ''
    $backendArg = Get-FolioBackendBaseUrlArg
    if (-not [string]::IsNullOrWhiteSpace($backendArg)) {
        $backendDefine = [string]$backendArg
    }
    $verSafe = Get-VersionForFileName (Get-PubspecVersionRaw)
    $zipName = "Folio-Linux-GitHub-${verSafe}.zip"
    $shPathWin = Join-Path $env:TEMP 'folio_build_linux_wsl.sh'
    $shContent = @"
#!/usr/bin/env bash
set -euo pipefail
cd '$wslRoot'
if ! command -v flutter >/dev/null 2>&1; then
  echo 'WSL: flutter no esta en PATH. Instala Flutter en la distro o usa el job ubuntu de CI.' >&2
  exit 127
fi
if ! command -v zip >/dev/null 2>&1; then
  echo 'WSL: zip no esta instalado (sudo apt install zip).' >&2
  exit 127
fi
flutter pub get
flutter build linux --release $distDefine $webDefine $backendDefine
mkdir -p '$wslOut'
rm -f '$wslOut/$zipName'
(cd build/linux/x64/release && zip -r '$wslOut/$zipName' bundle)
echo "ZIP Linux (WSL): $wslOut/$zipName"
"@
    # LF endings for bash
    [System.IO.File]::WriteAllText($shPathWin, ($shContent -replace "`r`n", "`n"))
    $shPathWsl = ConvertTo-WslPath $shPathWin
    & wsl.exe -e bash $shPathWsl
    if ($LASTEXITCODE -ne 0) {
        throw "Fallo build Linux via WSL (codigo $LASTEXITCODE)."
    }
    $zipPath = Join-Path $OutputDir $zipName
    if (Test-Path -LiteralPath $zipPath) {
        Write-Host "[ok] ZIP Linux (WSL): $zipPath" -ForegroundColor Green
    } else {
        throw "WSL termino OK pero no se encontro $zipPath"
    }
}

# Intenta Linux nativo; si estamos en Windows, prueba WSL. Best-effort si -BestEffort.
function Build-Linux {
    param([switch] $BestEffort)
    try {
        if (Test-IsLinuxHost) {
            Build-LinuxNative
            return
        }
        if (Test-WslAvailable) {
            Build-LinuxViaWsl
            return
        }
        $msg = 'Omitiendo Linux: no hay entorno Linux/WSL. Usa WSL (Ubuntu) o el job linux del workflow folio-build-all.'
        if ($BestEffort) {
            Write-Host "`n[warn] $msg" -ForegroundColor Magenta
            return
        }
        throw $msg
    } catch {
        if ($BestEffort) {
            Write-Host "`n[warn] Linux no compilado: $($_.Exception.Message)" -ForegroundColor Magenta
            return
        }
        throw
    }
}

function Build-MacOS {
    param([switch] $BestEffort)
    if (-not (Test-IsMacOSHost)) {
        $msg = 'Omitiendo macOS: solo se puede compilar en un host macOS (no hay cross-compile). Usa el job macos del workflow folio-build-all.'
        if ($BestEffort) {
            Write-Host "`n[warn] $msg" -ForegroundColor Magenta
            return
        }
        throw $msg
    }
    try {
        Write-Host "`n[macos] Compilando macOS (Release)..." -ForegroundColor Cyan
        $macArgs = Merge-FlutterDartDefines @('build', 'macos', '--release') @(
            (Get-FolioDistributionArg $DistributionMacOS),
            (Get-FolioWebBaseUrlArg),
            (Get-FolioBackendBaseUrlArg)
        )
        & flutter @macArgs
        Assert-LastExitCode 'flutter build macos'
        Write-Host 'macOS listo.' -ForegroundColor Green
        Copy-MacOSAppZip
    } catch {
        if ($BestEffort) {
            Write-Host "`n[warn] macOS no compilado: $($_.Exception.Message)" -ForegroundColor Magenta
            return
        }
        throw
    }
}

# ---------------------------------------------------------------------------
# Instalador Windows (Inno Setup) -> Folio-Setup-<semver>.exe
# Fuente unica: installer/folio_setup.iss.template via tool/windows/build_installer.ps1
# ---------------------------------------------------------------------------

function Find-Iscc {
    $cmd = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    # Prefer Inno Setup 7, then 6/5. Compile with ISCC.exe (CLI), not ISIDE.exe (IDE).
    $candidates = @(
        (Join-Path $env:ProgramFiles 'Inno Setup 7\ISCC.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 7\ISCC.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 7\ISCC.exe'),
        (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 5\ISCC.exe'),
        (Join-Path $env:ProgramFiles 'Inno Setup 5\ISCC.exe')
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) { return $candidate }
    }

    $regRoots = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 7_is1',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 7_is1',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 7_is1',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1'
    )
    foreach ($root in $regRoots) {
        $loc = (Get-ItemProperty -Path $root -Name 'InstallLocation' -ErrorAction SilentlyContinue).InstallLocation
        if ($loc) {
            $iscc = Join-Path $loc 'ISCC.exe'
            if (Test-Path -LiteralPath $iscc) { return $iscc }
        }
    }
    return $null
}

# Compila Windows (GitHub) si hace falta y genera el instalador .exe en Output.
# Devuelve la ruta del instalador generado.
function Build-WindowsInstaller {
    param(
        [switch] $ForceRebuild
    )
    Build-WindowsGitHub

    if (-not (Find-Iscc)) {
        throw "No se encontro ISCC.exe (Inno Setup). Instalalo con 'winget install JRSoftware.InnoSetup' o 'choco install innosetup'."
    }

    $release = Join-Path $RepoRoot 'build\windows\x64\runner\Release'
    $builder = Join-Path $RepoRoot 'tool\windows\build_installer.ps1'
    if (-not (Test-Path -LiteralPath $builder)) {
        throw "No se encontro $builder"
    }

    $semver = Get-PubspecSemver
    $outputBase = "Folio-Setup-$semver"
    $installerPath = & $builder `
        -RepoRoot $RepoRoot `
        -SourceDir $release `
        -OutputDir $OutputDir `
        -AppVersion $semver `
        -OutputBase $outputBase
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "build_installer.ps1 failed with exit code $LASTEXITCODE"
    }
    # Script writes path to output stream; take last non-empty line.
    if ($installerPath -is [array]) {
        $installerPath = ($installerPath | Where-Object { $_ -and "$_".Trim() } | Select-Object -Last 1)
    }
    $installerPath = "$installerPath".Trim()
    if (-not $installerPath -or -not (Test-Path -LiteralPath $installerPath)) {
        $fallback = Join-Path $OutputDir "$outputBase.exe"
        if (Test-Path -LiteralPath $fallback) { return $fallback }
        throw "No se genero el instalador esperado: $outputBase.exe"
    }
    return $installerPath
}

# ---------------------------------------------------------------------------
# Publicacion en GitHub (gh CLI)
# ---------------------------------------------------------------------------

# Resuelve el target_commitish valido para la release:
# 1) -ReleaseTarget si se pasa. 2) rama actual si existe en el remoto.
# 3) rama por defecto del remoto (origin/HEAD). 4) 'main'.
function Resolve-ReleaseTarget {
    if (-not [string]::IsNullOrWhiteSpace($ReleaseTarget)) {
        return $ReleaseTarget.Trim()
    }
    $branch = (& git rev-parse --abbrev-ref HEAD 2>$null)
    if ($LASTEXITCODE -eq 0 -and $branch -and $branch -ne 'HEAD') {
        & git show-ref --verify --quiet "refs/remotes/origin/$branch" 2>$null
        if ($LASTEXITCODE -eq 0) {
            $global:LASTEXITCODE = 0
            return $branch
        }
    }
    $def = (& git symbolic-ref --short refs/remotes/origin/HEAD 2>$null)
    $global:LASTEXITCODE = 0
    if ($def) {
        return ($def -replace '^origin/', '')
    }
    return 'main'
}

function Assert-GhReady {
    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $gh) {
        throw "No se encontro GitHub CLI (gh). Instalalo con 'winget install GitHub.cli'."
    }
    & gh auth status *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "GitHub CLI no esta autenticado. Ejecuta 'gh auth login' y reintenta."
    }
}

# Resuelve el cuerpo Markdown de la release.
# Prioridad: -ReleaseNotesFile > -ReleaseNotes > pegado interactivo > $null (= --generate-notes).
# Devuelve $null para autogenerar con gh, o un string Markdown.
function Resolve-ReleaseNotes {
    if (-not [string]::IsNullOrWhiteSpace($ReleaseNotesFile)) {
        $path = $ReleaseNotesFile.Trim()
        if (-not (Test-Path -LiteralPath $path)) {
            throw "No se encontro el archivo de notas: $path"
        }
        $full = (Resolve-Path -LiteralPath $path).Path
        Write-Host "[release] Notas desde archivo: $full" -ForegroundColor Gray
        return [System.IO.File]::ReadAllText($full, [System.Text.UTF8Encoding]::new($false))
    }

    if (-not [string]::IsNullOrWhiteSpace($ReleaseNotes)) {
        Write-Host "[release] Notas desde -ReleaseNotes" -ForegroundColor Gray
        return $ReleaseNotes
    }

    # CI / -Yes: sin prompt, autogenerar.
    if ($Yes -or $NonInteractive) {
        return $null
    }

    Write-Host ""
    Write-Host "Notas de la release (Markdown):" -ForegroundColor Yellow
    Write-Host "  - Pulsa Enter en la primera linea para generar notas automaticamente (gh --generate-notes)." -ForegroundColor Gray
    Write-Host "  - O pega el Markdown y termina con una linea que diga solo: END" -ForegroundColor Gray
    Write-Host ""

    $lines = [System.Collections.Generic.List[string]]::new()
    $first = $true
    while ($true) {
        $line = Read-Host
        if ($first -and [string]::IsNullOrWhiteSpace($line)) {
            Write-Host "[release] Sin notas pegadas; se usara --generate-notes." -ForegroundColor Gray
            return $null
        }
        $first = $false
        if ($line -eq 'END') { break }
        [void]$lines.Add($line)
    }

    $body = ($lines -join "`n").TrimEnd()
    if ([string]::IsNullOrWhiteSpace($body)) {
        Write-Host "[release] Notas vacias; se usara --generate-notes." -ForegroundColor Gray
        return $null
    }

    Write-Host ("[release] Notas Markdown recibidas ({0} caracteres)." -f $body.Length) -ForegroundColor Gray
    return $body
}

function Get-ReleaseTagForScope {
    param(
        [Parameter(Mandatory)] [string] $Semver,
        [string] $Scope = 'global'
    )
    if (-not [string]::IsNullOrWhiteSpace($ReleaseTag)) {
        return $ReleaseTag.Trim()
    }
    $scopeNorm = $Scope.Trim().ToLowerInvariant()
    if ($scopeNorm -eq 'global' -or [string]::IsNullOrWhiteSpace($scopeNorm)) {
        return "v$Semver"
    }
    return "v$Semver-$scopeNorm"
}

function Get-OutputReleaseAssetsForScope {
    param([string] $Scope = 'global')
    $all = @(Get-OutputReleaseAssets)
    $scopeNorm = $Scope.Trim().ToLowerInvariant()
    if ($scopeNorm -eq 'global' -or [string]::IsNullOrWhiteSpace($scopeNorm)) {
        return $all
    }
    $filtered = [System.Collections.Generic.List[string]]::new()
    foreach ($path in $all) {
        $leaf = Split-Path $path -Leaf
        $include = $false
        switch ($scopeNorm) {
            'android' { $include = $leaf -like 'Folio-Android-*' }
            'windows' {
                $include = ($leaf -like 'Folio-Setup-*.exe') -or
                    ($leaf -like 'Folio-Windows-GitHub-*.zip') -or
                    ($leaf -like 'Folio-MicrosoftStore-*.msix')
            }
            'linux' { $include = $leaf -like 'Folio-Linux-*' }
            'macos' { $include = $leaf -like 'Folio-macOS-*' }
        }
        if ($include) { $filtered.Add($path) }
    }
    return $filtered.ToArray()
}

function Publish-Release {
    param(
        [Parameter(Mandatory)] [string] $Tag,
        [string] $InstallerPath = '',
        [string[]] $AssetPaths = @(),
        [string] $NotesBody = '',
        [switch] $AsPreRelease,
        [switch] $AsDraft
    )
    Assert-GhReady

    $assets = [System.Collections.Generic.List[string]]::new()
    if (-not [string]::IsNullOrWhiteSpace($InstallerPath)) {
        $assets.Add($InstallerPath)
    }
    foreach ($a in @($AssetPaths)) {
        if ([string]::IsNullOrWhiteSpace($a)) { continue }
        if (-not (Test-Path -LiteralPath $a)) {
            Write-Warning "Asset no encontrado, se omite: $a"
            continue
        }
        if (-not ($assets -contains $a)) {
            $assets.Add($a)
        }
    }

    & gh release view $Tag *> $null
    $releaseExists = ($LASTEXITCODE -eq 0)
    $global:LASTEXITCODE = 0

    if ($releaseExists) {
        if ($assets.Count -eq 0) {
            throw "Ya existe la release '$Tag' y no hay assets nuevos que subir."
        }
        Write-Host "`n[release] El tag '$Tag' ya existe; subiendo/actualizando assets..." -ForegroundColor Cyan
        foreach ($a in $assets) {
            Write-Host "    - $(Split-Path $a -Leaf)" -ForegroundColor Gray
        }
        & gh release upload $Tag @($assets.ToArray()) --clobber
        Assert-LastExitCode 'gh release upload'
        Write-Host "Assets actualizados en: $Tag" -ForegroundColor Green
        return
    }

    $target = Resolve-ReleaseTarget

    $notesFile = $null
    try {
        $ghArgs = [System.Collections.Generic.List[string]]::new()
        $ghArgs.Add('release'); $ghArgs.Add('create'); $ghArgs.Add($Tag)
        foreach ($a in $assets) {
            $ghArgs.Add($a)
        }
        $ghArgs.Add('--target'); $ghArgs.Add($target)
        $ghArgs.Add('--title'); $ghArgs.Add($Tag)

        if (-not [string]::IsNullOrWhiteSpace($NotesBody)) {
            $notesFile = Join-Path ([System.IO.Path]::GetTempPath()) ("folio-release-notes-" + [guid]::NewGuid().ToString('N') + '.md')
            [System.IO.File]::WriteAllText($notesFile, $NotesBody, [System.Text.UTF8Encoding]::new($false))
            $ghArgs.Add('--notes-file'); $ghArgs.Add($notesFile)
        } else {
            $ghArgs.Add('--generate-notes')
        }

        if ($AsPreRelease) { $ghArgs.Add('--prerelease') }
        if ($AsDraft) { $ghArgs.Add('--draft') }

        $kind = if ($AsPreRelease) { 'PRE-RELEASE (Beta)' } else { 'RELEASE estable' }
        $notesMode = if (-not [string]::IsNullOrWhiteSpace($NotesBody)) { 'Markdown pegado/archivo' } else { 'autogeneradas (gh)' }
        Write-Host "`n[release] Publicando $kind '$Tag' en GitHub..." -ForegroundColor Cyan
        Write-Host "  Target : $target" -ForegroundColor Gray
        Write-Host "  Notas  : $notesMode" -ForegroundColor Gray
        Write-Host "  Assets : $($assets.Count)" -ForegroundColor Gray
        foreach ($a in $assets) {
            Write-Host "    - $(Split-Path $a -Leaf)" -ForegroundColor Gray
        }
        & gh @ghArgs
        Assert-LastExitCode 'gh release create'
        Write-Host "Publicado: $Tag" -ForegroundColor Green
    } finally {
        if ($notesFile -and (Test-Path -LiteralPath $notesFile)) {
            Remove-Item -LiteralPath $notesFile -Force -ErrorAction SilentlyContinue
        }
    }
}

# Flujo completo de publicacion (release o pre-release).
# Alcance: global (vX.Y.Z) o plataforma (vX.Y.Z-<platform>), elegido por menu.
function Invoke-PublishFlow {
    param([switch] $AsPreRelease)

    if (-not [string]::IsNullOrWhiteSpace($BumpVersion)) {
        Set-PubspecVersion $BumpVersion
    }

    $scope = $PlatformScope.Trim().ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($scope)) { $scope = 'global' }

    $semver = Get-PubspecSemver
    $tag = Get-ReleaseTagForScope -Semver $semver -Scope $scope

    $kind = if ($AsPreRelease) { 'PRE-RELEASE (Beta)' } else { 'RELEASE estable' }
    $script:FolioWebChannel = if ($AsPreRelease) { 'beta' } else { 'production' }
    $webLinks = if ($AsPreRelease) {
        'https://foliobeta.minealexgames.com'
    } else {
        'https://folio.minealexgames.com'
    }
    $backendUrl = if ($AsPreRelease) {
        'https://api-beta.folio.com.es'
    } else {
        'https://backendfolio.minealexgames.com'
    }

    # Ajustar skips segun alcance de plataforma.
    $prevSkipAndroid = $SkipAndroid
    $prevSkipLinux = $SkipLinux
    $prevSkipMacOS = $SkipMacOS
    $prevSkipStore = $SkipMicrosoftStore
    $prevSkipWindows = $script:FolioPublishSkipWindows
    $buildWindows = $true
    try {
        switch ($scope) {
            'android' {
                $SkipAndroid = $false
                $SkipLinux = $true
                $SkipMacOS = $true
                $SkipMicrosoftStore = $true
                $buildWindows = $false
            }
            'windows' {
                $SkipAndroid = $true
                $SkipLinux = $true
                $SkipMacOS = $true
                $buildWindows = $true
            }
            'linux' {
                $SkipAndroid = $true
                $SkipLinux = $false
                $SkipMacOS = $true
                $SkipMicrosoftStore = $true
                $buildWindows = $false
            }
            'macos' {
                $SkipAndroid = $true
                $SkipLinux = $true
                $SkipMacOS = $false
                $SkipMicrosoftStore = $true
                $buildWindows = $false
            }
            default {
                # global: Skip* y FolioPublishSkipWindows vienen del menu de plataformas
                $buildWindows = -not $script:FolioPublishSkipWindows
            }
        }

        Write-Host "`n----------------------------------------------" -ForegroundColor DarkGray
        Write-Host " $kind" -ForegroundColor Cyan
        Write-Host "  Version pubspec : $(Get-PubspecVersionRaw)" -ForegroundColor Gray
        Write-Host "  Alcance         : $scope" -ForegroundColor Gray
        Write-Host "  Tag GitHub      : $tag" -ForegroundColor Gray
        Write-Host "  Destino (target): $(Resolve-ReleaseTarget)" -ForegroundColor Gray
        Write-Host "  Enlaces web     : $webLinks (compartir / reset / verify)" -ForegroundColor Gray
        Write-Host "  Backend API     : $backendUrl" -ForegroundColor Gray
        Write-Host "----------------------------------------------" -ForegroundColor DarkGray

        if (-not (Confirm-Action "Compilar y publicar $tag (alcance=$scope) ?")) {
            Write-Host "Cancelado." -ForegroundColor Yellow
            return
        }

        $notesBody = Resolve-ReleaseNotes
        if ($null -eq $notesBody) { $notesBody = '' }

        Assert-GhReady

        $needInstaller = $false
        if ($scope -eq 'windows') { $needInstaller = $true }
        elseif ($scope -eq 'global' -and $buildWindows) { $needInstaller = $true }

        if ($Clean) { Invoke-FlutterClean }
        Invoke-FlutterPubGet

        if ($buildWindows) {
            Build-WindowsGitHub
            if (-not $SkipMicrosoftStore) {
                Build-WindowsStore
            } else {
                Write-Host "`n[skip] Omitido: build Microsoft Store / MSIX." -ForegroundColor Magenta
            }
        } else {
            Write-Host "`n[skip] Omitido: builds Windows (alcance=$scope)." -ForegroundColor Magenta
        }

        if (-not $SkipAndroid) {
            Build-Android
        } else {
            Write-Host "`n[skip] Omitido: Android." -ForegroundColor Magenta
        }

        if ($SkipLinux) {
            Write-Host "`n[skip] Omitido: Linux." -ForegroundColor Magenta
        } else {
            Build-Linux -BestEffort
        }

        if ($SkipMacOS) {
            Write-Host "`n[skip] Omitido: macOS." -ForegroundColor Magenta
        } else {
            Build-MacOS -BestEffort
        }

        if ($needInstaller) {
            Write-Host "`n[installer] Generando instalador de Windows..." -ForegroundColor Yellow
            $iscc = Find-Iscc
            if ($iscc) {
                Build-WindowsInstaller -ForceRebuild:$false
            } else {
                throw "No se encontro ISCC.exe (Inno Setup). Instalalo con 'winget install JRSoftware.InnoSetup'."
            }
        }

        $assets = @(Get-OutputReleaseAssetsForScope -Scope $scope)
        if ($assets.Count -eq 0) {
            throw "No hay artefactos para publicar (alcance=$scope). Compila antes o revisa Output/."
        }

        Write-Host "`nArtefactos a publicar ($($assets.Count)):" -ForegroundColor Cyan
        foreach ($a in $assets) {
            Write-Host "  - $(Split-Path $a -Leaf)" -ForegroundColor Gray
        }

        Publish-Release -Tag $tag -AssetPaths $assets -NotesBody $notesBody -AsPreRelease:$AsPreRelease -AsDraft:$DraftRelease
    } finally {
        $SkipAndroid = $prevSkipAndroid
        $SkipLinux = $prevSkipLinux
        $SkipMacOS = $prevSkipMacOS
        $SkipMicrosoftStore = $prevSkipStore
        $script:FolioPublishSkipWindows = $prevSkipWindows
    }
}

# Flujo compilar todo localmente (comportamiento legado).
# -RequireInstaller: falla si no hay Inno Setup (necesario para publicar).
function Invoke-BuildAll {
    param([switch] $RequireInstaller)

    if ($Clean) { Invoke-FlutterClean }
    Invoke-FlutterPubGet

    Build-WindowsGitHub

    if (-not $SkipMicrosoftStore) {
        Build-WindowsStore
    } else {
        Write-Host "`n[skip] Omitido: build Microsoft Store / MSIX (-SkipMicrosoftStore)." -ForegroundColor Magenta
    }

    if (-not $SkipAndroid) {
        Build-Android
    } else {
        Write-Host "`n[skip] Omitido: Android (-SkipAndroid)." -ForegroundColor Magenta
    }

    if ($SkipLinux) {
        Write-Host "`n[skip] Omitido: Linux (-SkipLinux)." -ForegroundColor Magenta
    } else {
        # En Windows: intenta WSL; en Linux: nativo. Si no hay entorno, solo avisa.
        Build-Linux -BestEffort
    }

    if ($SkipMacOS) {
        Write-Host "`n[skip] Omitido: macOS (-SkipMacOS)." -ForegroundColor Magenta
    } else {
        Build-MacOS -BestEffort
    }

    # Generar instalador de Windows
    Write-Host "`n[installer] Generando instalador de Windows..." -ForegroundColor Yellow
    $iscc = Find-Iscc
    if ($iscc) {
        Build-WindowsInstaller -ForceRebuild:$false
    } elseif ($RequireInstaller) {
        throw "No se encontro ISCC.exe (Inno Setup). Instalalo con 'winget install JRSoftware.InnoSetup'."
    } else {
        Write-Host "[warn] No se encontro Inno Setup (iscc.exe). Omitiendo instalador." -ForegroundColor Magenta
        Write-Host "Instala Inno Setup desde: https://jrsoftware.org/isdl.php" -ForegroundColor Gray
    }
}

# ---------------------------------------------------------------------------
# Menu interactivo (uso humano: solo selectores numerados)
# ---------------------------------------------------------------------------

function Show-Menu {
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "            FOLIO - Compilar y publicar" -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host ("  Version actual (pubspec.yaml): {0}" -f (Get-PubspecVersionRaw)) -ForegroundColor Gray
    Write-Host ""
    Write-Host "  PUBLICAR EN GITHUB" -ForegroundColor Yellow
    Write-Host "   1) RELEASE estable"
    Write-Host "   2) PRE-RELEASE / Beta"
    Write-Host "   3) Solo notas (changelog, sin artefactos)"
    Write-Host ""
    Write-Host "  COMPILAR (local, sin publicar)" -ForegroundColor Yellow
    Write-Host "   4) Compilar TODO (lo posible en este PC)"
    Write-Host "   5) Solo instalador Windows (.exe)"
    Write-Host "   6) Solo Windows GitHub (ZIP)"
    Write-Host "   7) Solo Windows Microsoft Store (MSIX)"
    Write-Host "   8) Solo Android (APK + AAB)"
    Write-Host "   9) Solo Linux (ZIP)"
    Write-Host "  10) Solo macOS (ZIP)"
    Write-Host ""
    Write-Host "  MANTENIMIENTO" -ForegroundColor Yellow
    Write-Host "  11) flutter clean"
    Write-Host "  12) Cambiar version en pubspec.yaml"
    Write-Host ""
    Write-Host "   0) Salir"
    Write-Host ""
    $choice = Read-Host "Elige una opcion"
    switch ($choice) {
        '1' { return 'release' }
        '2' { return 'prerelease' }
        '3' { return 'notes' }
        '4' { return 'build-all' }
        '5' { return 'installer' }
        '6' { return 'windows' }
        '7' { return 'store' }
        '8' { return 'android' }
        '9' { return 'linux' }
        '10' { return 'macos' }
        '11' { return 'clean' }
        '12' { return 'bump' }
        '0' { return 'exit' }
        default {
            Write-Host "Opcion no valida." -ForegroundColor Red
            return 'menu'
        }
    }
}

# Devuelve 'global'|'android'|... o $null si cancela.
function Read-PlatformScopeInteractive {
    Write-Host ""
    Write-Host "Alcance de publicacion (tag en GitHub):" -ForegroundColor Yellow
    Write-Host "  1) Global     -> vX.Y.Z          (todas las plataformas que elijas)"
    Write-Host "  2) Android    -> vX.Y.Z-android"
    Write-Host "  3) Windows    -> vX.Y.Z-windows"
    Write-Host "  4) Linux      -> vX.Y.Z-linux"
    Write-Host "  5) macOS      -> vX.Y.Z-macos"
    Write-Host "  0) Cancelar"
    Write-Host ""
    $ans = (Read-Host "Elige una opcion").Trim()
    switch ($ans) {
        '1' { return 'global' }
        '2' { return 'android' }
        '3' { return 'windows' }
        '4' { return 'linux' }
        '5' { return 'macos' }
        '0' { return $null }
        default {
            Write-Host "Opcion no valida." -ForegroundColor Red
            return $null
        }
    }
}

# Solo para alcance global: toggles numerados de que plataformas incluir.
function Read-GlobalPlatformIncludesInteractive {
    $includeWindows = $true
    $includeMsix = $true
    $includeAndroid = $true
    $includeLinux = $true
    $includeMacOS = $true

    while ($true) {
        $mark = {
            param([bool]$on)
            if ($on) { '[X]' } else { '[ ]' }
        }
        Write-Host ""
        Write-Host "Release GLOBAL: elige plataformas a incluir" -ForegroundColor Yellow
        Write-Host ("  1) Windows ZIP + instalador  {0}" -f (& $mark $includeWindows))
        Write-Host ("  2) Microsoft Store (MSIX)    {0}" -f (& $mark $includeMsix))
        Write-Host ("  3) Android (APK + AAB)       {0}" -f (& $mark $includeAndroid))
        Write-Host ("  4) Linux                     {0}" -f (& $mark $includeLinux))
        Write-Host ("  5) macOS                     {0}" -f (& $mark $includeMacOS))
        Write-Host "  6) Continuar con esta seleccion"
        Write-Host "  0) Cancelar"
        Write-Host ""
        $ans = (Read-Host "Elige (1-5 para alternar, 6 para seguir)").Trim()
        switch ($ans) {
            '1' { $includeWindows = -not $includeWindows }
            '2' { $includeMsix = -not $includeMsix }
            '3' { $includeAndroid = -not $includeAndroid }
            '4' { $includeLinux = -not $includeLinux }
            '5' { $includeMacOS = -not $includeMacOS }
            '6' {
                if (-not $includeWindows -and -not $includeAndroid -and -not $includeLinux -and -not $includeMacOS) {
                    Write-Host "Debes incluir al menos una plataforma." -ForegroundColor Red
                    continue
                }
                if ($includeMsix -and -not $includeWindows) {
                    Write-Host "MSIX requiere Windows; se desactiva MSIX." -ForegroundColor Yellow
                    $includeMsix = $false
                }
                return [pscustomobject]@{
                    IncludeWindows = $includeWindows
                    IncludeMsix    = $includeMsix
                    IncludeAndroid = $includeAndroid
                    IncludeLinux   = $includeLinux
                    IncludeMacOS   = $includeMacOS
                }
            }
            '0' { return $null }
            default { Write-Host "Opcion no valida." -ForegroundColor Red }
        }
    }
}

# Notas: estable vs beta por menu.
function Read-NotesChannelInteractive {
    Write-Host ""
    Write-Host "Canal de las notas:" -ForegroundColor Yellow
    Write-Host "  1) RELEASE estable"
    Write-Host "  2) PRE-RELEASE / Beta"
    Write-Host "  0) Cancelar"
    Write-Host ""
    $ans = (Read-Host "Elige una opcion").Trim()
    switch ($ans) {
        '1' { return 'stable' }
        '2' { return 'beta' }
        '0' { return $null }
        default {
            Write-Host "Opcion no valida." -ForegroundColor Red
            return $null
        }
    }
}

function Confirm-Action([string] $message) {
    if ($Yes) { return $true }
    Write-Host ""
    Write-Host $message -ForegroundColor Yellow
    Write-Host "  1) Si"
    Write-Host "  2) No"
    $answer = (Read-Host "Elige una opcion").Trim()
    return ($answer -eq '1')
}

# Ejecuta una accion concreta.
function Invoke-FolioAction([string] $act) {
    switch ($act) {
        'build-all' { Invoke-BuildAll }
        'release' {
            $scope = Read-PlatformScopeInteractive
            if ($null -eq $scope) {
                Write-Host "Cancelado." -ForegroundColor Yellow
                return
            }
            $script:PlatformScope = $scope
            if ($scope -eq 'global') {
                $includes = Read-GlobalPlatformIncludesInteractive
                if ($null -eq $includes) {
                    Write-Host "Cancelado." -ForegroundColor Yellow
                    return
                }
                $script:SkipAndroid = -not $includes.IncludeAndroid
                $script:SkipLinux = -not $includes.IncludeLinux
                $script:SkipMacOS = -not $includes.IncludeMacOS
                $script:SkipMicrosoftStore = -not $includes.IncludeMsix
                $script:FolioPublishSkipWindows = -not $includes.IncludeWindows
            } else {
                $script:FolioPublishSkipWindows = $false
            }
            Invoke-PublishFlow
        }
        'prerelease' {
            $scope = Read-PlatformScopeInteractive
            if ($null -eq $scope) {
                Write-Host "Cancelado." -ForegroundColor Yellow
                return
            }
            $script:PlatformScope = $scope
            if ($scope -eq 'global') {
                $includes = Read-GlobalPlatformIncludesInteractive
                if ($null -eq $includes) {
                    Write-Host "Cancelado." -ForegroundColor Yellow
                    return
                }
                $script:SkipAndroid = -not $includes.IncludeAndroid
                $script:SkipLinux = -not $includes.IncludeLinux
                $script:SkipMacOS = -not $includes.IncludeMacOS
                $script:SkipMicrosoftStore = -not $includes.IncludeMsix
                $script:FolioPublishSkipWindows = -not $includes.IncludeWindows
            } else {
                $script:FolioPublishSkipWindows = $false
            }
            Invoke-PublishFlow -AsPreRelease
        }
        'installer' {
            if ($Clean) { Invoke-FlutterClean }
            Invoke-FlutterPubGet
            [void](Build-WindowsInstaller -ForceRebuild:$Clean)
        }
        'windows' {
            if ($Clean) { Invoke-FlutterClean }
            Invoke-FlutterPubGet
            Build-WindowsGitHub
        }
        'store' {
            if ($Clean) { Invoke-FlutterClean }
            Invoke-FlutterPubGet
            Build-WindowsStore
        }
        'android' {
            if ($Clean) { Invoke-FlutterClean }
            Invoke-FlutterPubGet
            Build-Android
        }
        'linux' {
            if ($Clean) { Invoke-FlutterClean }
            Invoke-FlutterPubGet
            Build-Linux
        }
        'macos' {
            if ($Clean) { Invoke-FlutterClean }
            Invoke-FlutterPubGet
            Build-MacOS
        }
        'notes' {
            $channel = Read-NotesChannelInteractive
            if ($null -eq $channel) {
                Write-Host "Cancelado." -ForegroundColor Yellow
                return
            }
            $scope = Read-PlatformScopeInteractive
            if ($null -eq $scope) {
                Write-Host "Cancelado." -ForegroundColor Yellow
                return
            }
            $script:PlatformScope = $scope
            $semver = Get-PubspecSemver
            $tag = Get-ReleaseTagForScope -Semver $semver -Scope $scope
            $asPre = ($channel -eq 'beta')
            if (Confirm-Action "Publicar release solo-notas '$tag' ?") {
                $notesBody = Resolve-ReleaseNotes
                if ($null -eq $notesBody) { $notesBody = '' }
                Publish-Release -Tag $tag -NotesBody $notesBody -AsPreRelease:$asPre -AsDraft:$DraftRelease
            } else {
                Write-Host "Cancelado." -ForegroundColor Yellow
            }
        }
        'clean' { Invoke-FlutterClean }
        'bump' {
            $v = Read-Host "Nueva version (X.Y.Z o X.Y.Z+build)"
            Set-PubspecVersion $v
        }
        default { Write-Host "Accion desconocida: $act" -ForegroundColor Red }
    }
}

# ---------------------------------------------------------------------------
# Punto de entrada
# ---------------------------------------------------------------------------

Set-Location -LiteralPath $RepoRoot
Ensure-OutputDir

Write-Host "Folio - build & release (menus)" -ForegroundColor Cyan
Write-Host "Salida: $OutputDir" -ForegroundColor Gray
Write-Host "Ejecuta sin parametros y elige en pantalla." -ForegroundColor Gray

# Invocacion no interactiva solo para CI (si llegan Skip*/NonInteractive/Action).
$legacyInvocation = $SkipAndroid -or $SkipLinux -or $SkipMacOS -or $SkipMicrosoftStore -or $NonInteractive

if ([string]::IsNullOrWhiteSpace($Action)) {
    if ($legacyInvocation) {
        $Action = 'build-all'
    } else {
        $Action = 'menu'
    }
}

if ($Action -eq 'menu') {
    while ($true) {
        $picked = Show-Menu
        if ($picked -eq 'exit') { break }
        if ($picked -eq 'menu') { continue }
        try {
            Invoke-FolioAction $picked
        } catch {
            Write-Host "`n[ERROR] $($_.Exception.Message)" -ForegroundColor Red
        }
        Write-Host ""
        Read-Host "Pulsa Enter para volver al menu"
    }
    Write-Host "`nHasta luego." -ForegroundColor Green
} else {
    Invoke-FolioAction $Action
    Write-Host "`nProceso finalizado." -ForegroundColor Green
    Write-Host "Artefactos recogidos en: $OutputDir" -ForegroundColor Gray
}
