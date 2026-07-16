# Script de compilación y publicación multiplataforma para Folio
# Ver docs/RELEASES.md → sección FOLIO_DISTRIBUTION
#
# Uso interactivo (menú):   .\builld_all.ps1
# Uso directo (CI/scripts):  .\builld_all.ps1 -Action build-all -SkipAndroid -SkipLinux
#
# Acciones (-Action):
#   menu        Mostrar el menú interactivo (por defecto sin argumentos).
#   build-all   Compilar todo localmente (Windows ZIP + MSIX + APK + Linux) sin publicar.
#   release     Compilar instalador Windows y publicar RELEASE estable en GitHub.
#   prerelease  Compilar instalador Windows y publicar PRE-RELEASE (canal Beta) en GitHub.
#   installer   Generar solo el instalador Windows (.exe) sin publicar.
#   windows     Compilar solo Windows (canal GitHub) -> ZIP.
#   store       Compilar solo Windows (Microsoft Store) -> MSIX.
#   android     Compilar solo Android (APK).
#   linux       Compilar solo Linux (bundle -> ZIP).
#   notes       Publicar release "solo notas" (changelog) sin adjuntar instalador.
#   clean       Ejecutar flutter clean.
param(
    # Accion a ejecutar. Vacio = menu interactivo (o build-all si se usa modo no interactivo/CI).
    [ValidateSet('', 'menu', 'build-all', 'release', 'prerelease', 'installer', 'windows', 'store', 'android', 'linux', 'notes', 'clean')]
    [string] $Action = '',
    # Carpeta de salida (por defecto [repo]/Output).
    [string] $Output = '',
    # Vacio = no anade --dart-define (comportamiento legado en Windows).
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
    # Solo en maquinas Linux/WSL; en Windows omitir o usar job ubuntu.
    [switch] $SkipLinux,
    # Origen de MS_STORE_* para --dart-define (por defecto functions/.env).
    [string] $MicrosoftStoreEnvFile = '',
    # Ejecutar 'flutter clean' antes de compilar (evita caches CMake obsoletas al mover el repo).
    [switch] $Clean,
    # Forzar modo no interactivo (no muestra menu; usa -Action o build-all).
    [switch] $NonInteractive,
    # Tag de la release (por defecto v<semver de pubspec.yaml>).
    [string] $ReleaseTag = '',
    # Rama/commit destino de la release en GitHub. Vacio = autodetectar (rama actual o por defecto del remoto).
    [string] $ReleaseTarget = '',
    # Publicar como pre-release (canal Beta). release=estable, prerelease=beta.
    [switch] $PreRelease,
    # Publicar como borrador (draft) en GitHub.
    [switch] $DraftRelease,
    # Nueva version para pubspec.yaml antes de compilar (p. ej. 1.3.0 o 1.3.0+12). Vacio = mantener.
    [string] $BumpVersion = '',
    # No pedir confirmaciones interactivas en flujos de publicacion.
    [switch] $Yes
)

$ErrorActionPreference = 'Stop'

$RepoRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Output)) {
    $OutputDir = Join-Path $RepoRoot 'Output'
} else {
    $OutputDir = $Output.Trim()
}

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

# ---------------------------------------------------------------------------
# Builds por plataforma
# ---------------------------------------------------------------------------

function Build-WindowsGitHub {
    Write-Host "`n[win] Compilando Windows (Release, canal GitHub)..." -ForegroundColor Cyan
    $winGhArgs = Merge-FlutterDartDefines @('build', 'windows', '--release') @(
        (Get-FolioDistributionArg $DistributionWindowsGitHub)
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
        (Get-MicrosoftStoreDartDefinesFromEnv -EnvFilePath $msEnv)
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
        (Get-FolioDistributionArg $DistributionAndroid)
    )
    & flutter @apkArgs
    Assert-LastExitCode 'flutter build apk'
    Write-Host 'Android APK listo.' -ForegroundColor Green
    Copy-AndroidApk

    Write-Host "`n[android] Compilando Android (AAB Release)..." -ForegroundColor Cyan
    $aabArgs = Merge-FlutterDartDefines @('build', 'appbundle', '--release') @(
        (Get-FolioDistributionArg $DistributionAndroid)
    )
    & flutter @aabArgs
    Assert-LastExitCode 'flutter build appbundle'
    Write-Host 'Android AAB listo.' -ForegroundColor Green
    Copy-AndroidAab
}

function Build-Linux {
    Write-Host "`n[linux] Compilando Linux (Release)..." -ForegroundColor Cyan
    $linuxArgs = Merge-FlutterDartDefines @('build', 'linux', '--release') @(
        (Get-FolioDistributionArg $DistributionLinux)
    )
    & flutter @linuxArgs
    Assert-LastExitCode 'flutter build linux'
    Write-Host 'Linux listo.' -ForegroundColor Green
    Copy-LinuxBundleZip
}

# ---------------------------------------------------------------------------
# Instalador Windows (Inno Setup) -> Folio-Setup-<semver>.exe
# ---------------------------------------------------------------------------

function Find-Iscc {
    # 1) En el PATH.
    $cmd = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    # 2) Rutas de instalacion comunes (incluye instalacion por-usuario de winget).
    $candidates = @(
        (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
        (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 5\ISCC.exe'),
        (Join-Path $env:ProgramFiles 'Inno Setup 5\ISCC.exe')
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) { return $candidate }
    }

    # 3) Registro de desinstalacion de Inno Setup (InstallLocation).
    $regRoots = @(
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

    $release = Join-Path $RepoRoot 'build\windows\x64\runner\Release'
    $iscc = Find-Iscc
    if (-not $iscc) {
        throw "No se encontro ISCC.exe (Inno Setup). Instalalo con 'winget install JRSoftware.InnoSetup' o 'choco install innosetup'."
    }

    $mainExe = Get-ChildItem -LiteralPath $release -Filter '*.exe' -File |
        Where-Object { $_.Name -notmatch '^(vcruntime|msvcp|api-ms).*' } |
        Sort-Object Length -Descending |
        Select-Object -First 1
    if (-not $mainExe) {
        throw "No se encontro el ejecutable principal en $release."
    }

    $semver = Get-PubspecSemver
    $outputBase = "Folio-Setup-$semver"
    $sourceGlob = Join-Path $release '*'
    $icon = Join-Path $RepoRoot 'assets\icons\folio.ico'
    $iconLine = if (Test-Path -LiteralPath $icon) { "SetupIconFile=$icon" } else { '' }

    $iss = @"
#define MyAppName "Folio"
#define MyAppVersion "$semver"
#define MyAppPublisher "Minealex Games"
#define MyAppURL "https://minealexgames.com/"
#define MyAppExeName "$($mainExe.Name)"

[Setup]
AppId={{46CD296E-B5B7-433A-9063-C17444F19FBE}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
CloseApplications=yes
OutputDir=$OutputDir
OutputBaseFilename=$outputBase
$iconLine
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "$sourceGlob"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
"@

    $issPath = Join-Path $env:TEMP 'folio_installer.iss'
    Set-Content -LiteralPath $issPath -Value $iss -Encoding utf8

    Write-Host "`n[installer] Generando instalador con Inno Setup..." -ForegroundColor Cyan
    & $iscc $issPath
    Assert-LastExitCode 'ISCC (Inno Setup)'

    $installerPath = Join-Path $OutputDir "$outputBase.exe"
    if (-not (Test-Path -LiteralPath $installerPath)) {
        throw "No se genero el instalador esperado: $installerPath"
    }
    Write-Host "[ok] Instalador: $installerPath" -ForegroundColor Green
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

function Publish-Release {
    param(
        [Parameter(Mandatory)] [string] $Tag,
        [string] $InstallerPath = '',
        [switch] $AsPreRelease,
        [switch] $AsDraft
    )
    Assert-GhReady

    & gh release view $Tag *> $null
    if ($LASTEXITCODE -eq 0) {
        throw "Ya existe una release para el tag '$Tag'. Sube la version (pubspec.yaml) o borra la release."
    }
    $global:LASTEXITCODE = 0

    $target = Resolve-ReleaseTarget

    $ghArgs = [System.Collections.Generic.List[string]]::new()
    $ghArgs.Add('release'); $ghArgs.Add('create'); $ghArgs.Add($Tag)
    if (-not [string]::IsNullOrWhiteSpace($InstallerPath)) {
        $ghArgs.Add($InstallerPath)
    }
    $ghArgs.Add('--target'); $ghArgs.Add($target)
    $ghArgs.Add('--title'); $ghArgs.Add($Tag)
    $ghArgs.Add('--generate-notes')
    if ($AsPreRelease) { $ghArgs.Add('--prerelease') }
    if ($AsDraft) { $ghArgs.Add('--draft') }

    $kind = if ($AsPreRelease) { 'PRE-RELEASE (Beta)' } else { 'RELEASE estable' }
    Write-Host "`n[release] Publicando $kind '$Tag' en GitHub..." -ForegroundColor Cyan
    & gh @ghArgs
    Assert-LastExitCode 'gh release create'
    Write-Host "Publicado: $Tag" -ForegroundColor Green
}

function Confirm-Action([string] $message) {
    if ($Yes) { return $true }
    $answer = Read-Host "$message [s/N]"
    return ($answer -match '^(s|si|y|yes)$')
}

# Flujo completo de publicacion (release o pre-release).
function Invoke-PublishFlow {
    param([switch] $AsPreRelease)

    if (-not [string]::IsNullOrWhiteSpace($BumpVersion)) {
        Set-PubspecVersion $BumpVersion
    }

    $semver = Get-PubspecSemver
    $tag = if ([string]::IsNullOrWhiteSpace($ReleaseTag)) { "v$semver" } else { $ReleaseTag.Trim() }

    $kind = if ($AsPreRelease) { 'PRE-RELEASE (Beta)' } else { 'RELEASE estable' }
    Write-Host "`n----------------------------------------------" -ForegroundColor DarkGray
    Write-Host " $kind" -ForegroundColor Cyan
    Write-Host "  Version pubspec : $(Get-PubspecVersionRaw)" -ForegroundColor Gray
    Write-Host "  Tag GitHub      : $tag" -ForegroundColor Gray
    Write-Host "  Destino (target): $(Resolve-ReleaseTarget)" -ForegroundColor Gray
    Write-Host "----------------------------------------------" -ForegroundColor DarkGray

    if (-not (Confirm-Action "Compilar instalador y publicar $tag ?")) {
        Write-Host "Cancelado." -ForegroundColor Yellow
        return
    }

    Assert-GhReady
    if ($Clean) { Invoke-FlutterClean }
    Invoke-FlutterPubGet
    # No capturar la salida por stream: 'flutter'/'ISCC' contaminarian el valor de retorno.
    # La ruta del instalador es determinista (Folio-Setup-<semver>.exe en Output).
    Build-WindowsInstaller -ForceRebuild:$Clean
    $installer = Join-Path $OutputDir ("Folio-Setup-" + (Get-PubspecSemver) + ".exe")
    if (-not (Test-Path -LiteralPath $installer)) {
        throw "No se encontro el instalador esperado: $installer"
    }
    Publish-Release -Tag $tag -InstallerPath $installer -AsPreRelease:$AsPreRelease -AsDraft:$DraftRelease
}

# Flujo compilar todo localmente (comportamiento legado).
function Invoke-BuildAll {
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
    } elseif ($IsLinux -or $env:LSB_RELEASE -or $env:WSL_DISTRO_NAME) {
        Build-Linux
    } else {
        Write-Host "`n[warn] Omitiendo Linux: no se detecto entorno Linux/WSL." -ForegroundColor Magenta
        Write-Host "Pista: para compilar Linux desde Windows, usa WSL (Ubuntu/Debian)." -ForegroundColor Gray
    }

    # Generar instalador de Windows
    Write-Host "`n[installer] Generando instalador de Windows..." -ForegroundColor Yellow
    $iscc = Find-Iscc
    if ($iscc) {
        Build-WindowsInstaller -ForceRebuild:$false
    } else {
        Write-Host "[warn] No se encontro Inno Setup (iscc.exe). Omitiendo instalador." -ForegroundColor Magenta
        Write-Host "Instala Inno Setup desde: https://jrsoftware.org/isdl.php" -ForegroundColor Gray
    }
}

# ---------------------------------------------------------------------------
# Menu interactivo
# ---------------------------------------------------------------------------

function Show-Menu {
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "            FOLIO - Compilar y publicar" -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host ("  Version actual (pubspec.yaml): {0}" -f (Get-PubspecVersionRaw)) -ForegroundColor Gray
    Write-Host ""
    Write-Host "  PUBLICAR" -ForegroundColor Yellow
    Write-Host "   1) Publicar RELEASE estable en GitHub (instalador .exe + tag)"
    Write-Host "   2) Publicar PRE-RELEASE / Beta en GitHub (instalador .exe + tag)"
    Write-Host "   3) Publicar solo notas (changelog) sin instalador"
    Write-Host ""
    Write-Host "  COMPILAR (local, sin publicar)" -ForegroundColor Yellow
    Write-Host "   4) Compilar TODO (Windows ZIP + MSIX + APK + AAB + Linux + Instalador)"
    Write-Host "   5) Generar solo instalador Windows (.exe)"
    Write-Host "   6) Windows (canal GitHub) -> ZIP"
    Write-Host "   7) Windows (Microsoft Store) -> MSIX"
    Write-Host "   8) Android (APK + AAB)"
    Write-Host "   9) Linux (bundle -> ZIP)"
    Write-Host ""
    Write-Host "  MANTENIMIENTO" -ForegroundColor Yellow
    Write-Host "  10) flutter clean"
    Write-Host "  11) Cambiar version en pubspec.yaml"
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
        '10' { return 'clean' }
        '11' { return 'bump' }
        '0' { return 'exit' }
        default {
            Write-Host "Opcion no valida." -ForegroundColor Red
            return 'menu'
        }
    }
}

# Ejecuta una accion concreta.
function Invoke-FolioAction([string] $act) {
    switch ($act) {
        'build-all' { Invoke-BuildAll }
        'release'   { Invoke-PublishFlow }
        'prerelease' { Invoke-PublishFlow -AsPreRelease }
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
        'notes' {
            $semver = Get-PubspecSemver
            $tag = if ([string]::IsNullOrWhiteSpace($ReleaseTag)) { "v$semver" } else { $ReleaseTag.Trim() }
            if (Confirm-Action "Publicar release solo-notas '$tag' ?") {
                Publish-Release -Tag $tag -AsPreRelease:$PreRelease -AsDraft:$DraftRelease
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

Write-Host "Folio - build & release" -ForegroundColor Cyan
Write-Host "Salida: $OutputDir" -ForegroundColor Gray

# Invocacion no interactiva (CI / parametros directos)?
$legacyInvocation = $SkipAndroid -or $SkipLinux -or $SkipMicrosoftStore -or $NonInteractive

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
