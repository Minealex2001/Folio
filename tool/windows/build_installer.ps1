#Requires -Version 5.1
<#
.SYNOPSIS
  Builds the Folio Windows installer (Inno Setup) from installer/folio_setup.iss.template.

.DESCRIPTION
  Shared by builld_all.ps1 and .github/workflows/windows-release-on-merge.yml.
  Optionally downloads VC++ redistributable and Authenticode-signs the Setup.exe.

.PARAMETER RepoRoot
  FolioApp repository root (directory containing pubspec.yaml).

.PARAMETER SourceDir
  Flutter Windows Release output directory (contains folio.exe).

.PARAMETER OutputDir
  Directory for Folio-Setup-<semver>.exe

.PARAMETER AppVersion
  Semver string (e.g. 0.8.4). If empty, read from pubspec.yaml.

.PARAMETER OutputBase
  Base filename without .exe. Default Folio-Setup-<AppVersion>.

.PARAMETER PfxPath
  Optional path to code-signing PFX. Also accepts env WINDOWS_CODE_SIGN_PFX_PATH.

.PARAMETER PfxPassword
  Optional PFX password. Also accepts env WINDOWS_CODE_SIGN_PASSWORD.

.PARAMETER PfxBase64
  Optional base64-encoded PFX (CI). Also accepts env WINDOWS_CODE_SIGN_PFX_BASE64.

.PARAMETER SkipVcRedistDownload
  Do not download vc_redist.x64.exe (installer still builds; redist entry skipped if missing).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $RepoRoot,

    [Parameter(Mandatory = $true)]
    [string] $SourceDir,

    [Parameter(Mandatory = $true)]
    [string] $OutputDir,

    [string] $AppVersion = '',
    [string] $OutputBase = '',
    [string] $PfxPath = '',
    [string] $PfxPassword = '',
    [string] $PfxBase64 = '',
    [switch] $SkipVcRedistDownload
)

$ErrorActionPreference = 'Stop'

function Assert-LastExitCode([string] $Label) {
    if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "$Label failed with exit code $LASTEXITCODE"
    }
}

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

function Find-SignTool {
    $cmd = Get-Command signtool.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $kitsRoot = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\bin'
    if (Test-Path -LiteralPath $kitsRoot) {
        $found = Get-ChildItem -LiteralPath $kitsRoot -Recurse -Filter 'signtool.exe' -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match '\\x64\\signtool\.exe$' } |
            Sort-Object FullName -Descending |
            Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    return $null
}

function Get-PubspecSemver([string] $Root) {
    $pubspec = Join-Path $Root 'pubspec.yaml'
    $line = Get-Content -LiteralPath $pubspec | Where-Object { $_ -match '^version:\s*' } | Select-Object -First 1
    if (-not $line) { throw "No version: line in $pubspec" }
    $raw = ($line -replace '^version:\s*', '').Trim()
    return $raw.Split('+')[0].Trim()
}

function Ensure-VcRedist([string] $RedistDir, [switch] $SkipDownload) {
    $dest = Join-Path $RedistDir 'vc_redist.x64.exe'
    if (Test-Path -LiteralPath $dest) { return $dest }
    if ($SkipDownload) {
        Write-Warning "VC++ redistributable missing at $dest (SkipVcRedistDownload)."
        return $null
    }
    New-Item -ItemType Directory -Force -Path $RedistDir | Out-Null
    $url = 'https://aka.ms/vs/17/release/vc_redist.x64.exe'
    Write-Host "[installer] Descargando VC++ Redistributable x64..." -ForegroundColor Cyan
    try {
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
    } catch {
        Write-Warning "No se pudo descargar vc_redist.x64.exe: $_"
        return $null
    }
    if (-not (Test-Path -LiteralPath $dest)) { return $null }
    return $dest
}

function Resolve-PfxMaterial {
    param(
        [string] $Path,
        [string] $Password,
        [string] $Base64
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        $Path = $env:WINDOWS_CODE_SIGN_PFX_PATH
    }
    if ([string]::IsNullOrWhiteSpace($Password)) {
        $Password = $env:WINDOWS_CODE_SIGN_PASSWORD
    }
    if ([string]::IsNullOrWhiteSpace($Base64)) {
        $Base64 = $env:WINDOWS_CODE_SIGN_PFX_BASE64
    }

    $tempPfx = $null
    if (-not [string]::IsNullOrWhiteSpace($Base64)) {
        $tempPfx = Join-Path $env:TEMP ("folio_codesign_{0}.pfx" -f [guid]::NewGuid().ToString('N'))
        [IO.File]::WriteAllBytes($tempPfx, [Convert]::FromBase64String($Base64.Trim()))
        $Path = $tempPfx
    }

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    return [pscustomobject]@{
        Path     = $Path
        Password = $Password
        TempPath = $tempPfx
    }
}

function Invoke-CodeSign([string] $FilePath, $Pfx) {
    $signtool = Find-SignTool
    if (-not $signtool) {
        Write-Warning 'signtool.exe no encontrado; se omite la firma Authenticode.'
        return $false
    }

    $args = @(
        'sign',
        '/fd', 'SHA256',
        '/tr', 'http://timestamp.digicert.com',
        '/td', 'SHA256',
        '/f', $Pfx.Path
    )
    if (-not [string]::IsNullOrWhiteSpace($Pfx.Password)) {
        $args += @('/p', $Pfx.Password)
    }
    $args += $FilePath

    Write-Host "[installer] Firmando Authenticode: $FilePath" -ForegroundColor Cyan
    & $signtool @args
    Assert-LastExitCode 'signtool'
    return $true
}

# ---- main ----

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$SourceDir = (Resolve-Path -LiteralPath $SourceDir).Path
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$OutputDir = (Resolve-Path -LiteralPath $OutputDir).Path

$template = Join-Path $RepoRoot 'installer\folio_setup.iss.template'
if (-not (Test-Path -LiteralPath $template)) {
    throw "Plantilla no encontrada: $template"
}

$iscc = Find-Iscc
if (-not $iscc) {
    throw "No se encontro ISCC.exe (Inno Setup). Instalalo con 'winget install JRSoftware.InnoSetup' o 'choco install innosetup'."
}

$mainExe = Get-ChildItem -LiteralPath $SourceDir -Filter '*.exe' -File |
    Where-Object { $_.Name -notmatch '^(vcruntime|msvcp|api-ms).*' } |
    Sort-Object Length -Descending |
    Select-Object -First 1
if (-not $mainExe) {
    throw "No se encontro el ejecutable principal en $SourceDir."
}

if ([string]::IsNullOrWhiteSpace($AppVersion)) {
    $AppVersion = Get-PubspecSemver -Root $RepoRoot
}
if ([string]::IsNullOrWhiteSpace($OutputBase)) {
    $OutputBase = "Folio-Setup-$AppVersion"
}

$icon = Join-Path $RepoRoot 'assets\icons\folio.ico'
$wizardImage = Join-Path $RepoRoot 'installer\assets\wizard_image.bmp'
$wizardSmall = Join-Path $RepoRoot 'installer\assets\wizard_small.bmp'
$eulaEn = Join-Path $RepoRoot 'installer\assets\eula_en.txt'
$eulaEs = Join-Path $RepoRoot 'installer\assets\eula_es.txt'

foreach ($required in @($icon, $wizardImage, $wizardSmall, $eulaEn, $eulaEs)) {
    if (-not (Test-Path -LiteralPath $required)) {
        throw "Asset requerido no encontrado: $required"
    }
}

$redistDir = Join-Path $RepoRoot 'installer\redist'
$vcRedist = Ensure-VcRedist -RedistDir $redistDir -SkipDownload:$SkipVcRedistDownload
# Inno skipifsourcedoesntexist needs a path that may not exist; use placeholder when missing.
if (-not $vcRedist) {
    $vcRedist = Join-Path $redistDir 'vc_redist.x64.exe'
}

function Escape-IssPath([string] $Path) {
    # Inno paths on Windows use backslashes; keep as-is.
    return $Path
}

$issText = Get-Content -LiteralPath $template -Raw -Encoding UTF8
$replacements = @{
    '__APP_VERSION__'         = $AppVersion
    '__APP_EXE_NAME__'        = $mainExe.Name
    '__SOURCE_DIR__'          = (Escape-IssPath $SourceDir)
    '__OUTPUT_DIR__'          = (Escape-IssPath $OutputDir)
    '__OUTPUT_BASE__'         = $OutputBase
    '__SETUP_ICON__'          = (Escape-IssPath $icon)
    '__WIZARD_IMAGE__'        = (Escape-IssPath $wizardImage)
    '__WIZARD_SMALL_IMAGE__'  = (Escape-IssPath $wizardSmall)
    '__EULA_EN__'             = (Escape-IssPath $eulaEn)
    '__EULA_ES__'             = (Escape-IssPath $eulaEs)
    '__VCREDIST_PATH__'       = (Escape-IssPath $vcRedist)
}

foreach ($key in $replacements.Keys) {
    $issText = $issText.Replace($key, $replacements[$key])
}

$issPath = Join-Path $env:TEMP ("folio_installer_{0}.iss" -f [guid]::NewGuid().ToString('N'))
# UTF-8 with BOM helps Inno with non-ASCII in EULA paths / comments
$utf8Bom = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText($issPath, $issText, $utf8Bom)

Write-Host "`n[installer] Generando instalador con Inno Setup..." -ForegroundColor Cyan
Write-Host "  ISCC: $iscc" -ForegroundColor Gray
Write-Host "  Script: $issPath" -ForegroundColor Gray
& $iscc $issPath
Assert-LastExitCode 'ISCC (Inno Setup)'

$installerPath = Join-Path $OutputDir "$OutputBase.exe"
if (-not (Test-Path -LiteralPath $installerPath)) {
    throw "No se genero el instalador esperado: $installerPath"
}

$pfx = Resolve-PfxMaterial -Path $PfxPath -Password $PfxPassword -Base64 $PfxBase64
try {
    if ($pfx) {
        [void](Invoke-CodeSign -FilePath $installerPath -Pfx $pfx)
        Write-Host '[ok] Instalador firmado.' -ForegroundColor Green
    } else {
        Write-Warning 'Sin certificado Authenticode (WINDOWS_CODE_SIGN_PFX_*). Instalador sin firmar.'
    }
} finally {
    if ($pfx -and $pfx.TempPath -and (Test-Path -LiteralPath $pfx.TempPath)) {
        Remove-Item -LiteralPath $pfx.TempPath -Force -ErrorAction SilentlyContinue
    }
    Remove-Item -LiteralPath $issPath -Force -ErrorAction SilentlyContinue
}

Write-Host "[ok] Instalador: $installerPath" -ForegroundColor Green
Write-Output $installerPath
