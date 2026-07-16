# Reemplazo endurecido para cargokit de super_native_extensions (pub cache).
# - Normaliza \ a / antes de segmentar.
# - Omite segmentos vacíos.
# - Usa LiteralPath + Force (junctions / ocultos).
# - Si un paso falla, devuelve la ruta de entrada (CMake ya aplicó REALPATH).

function Resolve-Symlinks {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Position = 0, Mandatory)]
        [string] $Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }

    $norm = $Path.Trim() -replace '\\', '/'
    $separator = '/'
    [string[]] $parts = $norm.Split($separator, [StringSplitOptions]::RemoveEmptyEntries)

    [string] $realPath = ''
    foreach ($part in $parts) {
        if ($realPath -and -not $realPath.EndsWith($separator)) {
            $realPath += $separator
        }
        $realPath += $part

        $literal = $realPath -replace '/', '\'
        try {
            $item = Get-Item -LiteralPath $literal -Force -ErrorAction Stop
        } catch {
            return $norm
        }

        $target = $item.Target
        if ($target) {
            $t = if ($target -is [System.Array]) { $target[0] } else { $target }
            if ($t) {
                $realPath = ($t.ToString() -replace '\\', '/').TrimEnd('/')
            }
        }
    }
    $realPath
}

$in = $args[0]
if (-not $in) {
    Write-Host ''
    exit 0
}

$path = Resolve-Symlinks -Path $in
if (-not $path) {
    $path = $in
}
Write-Host $path
