# Arranca Folio apuntando al API Spring (local, beta, prod, o cualquier URL de Railway).
# Uso:
#   .\tool\run_folio_spring.ps1 -Target local
#   .\tool\run_folio_spring.ps1 -Target beta
#   .\tool\run_folio_spring.ps1 -Target prod
#   .\tool\run_folio_spring.ps1 -BaseUrl https://TU-SERVICIO.up.railway.app
#   .\tool\run_folio_spring.ps1 -BaseUrl http://127.0.0.1:18080
#   $env:FOLIO_BACKEND_BASE_URL = 'https://…'; .\tool\run_folio_spring.ps1
#   .\tool\run_folio_spring.ps1 -Target beta -Device chrome

param(
  [ValidateSet('local', 'beta', 'prod')]
  [string]$Target,
  [string]$BaseUrl = $env:FOLIO_BACKEND_BASE_URL,
  [string]$Device = 'windows'
)

$presets = @{
  local = 'http://127.0.0.1:18080'
  beta  = 'https://api-beta.folio.com.es'
  prod  = 'https://api.folio.com.es'
}

if ($Target) {
  if (-not [string]::IsNullOrWhiteSpace($BaseUrl) -and $BaseUrl -ne $presets[$Target]) {
    Write-Warning "-Target $Target y -BaseUrl fueron especificados a la vez; se usa -BaseUrl ($BaseUrl)."
  } else {
    $BaseUrl = $presets[$Target]
  }
}

if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
  Write-Error @"
Falta la URL del API. Usa uno de:
  -Target local   ($($presets.local))
  -Target beta    ($($presets.beta))
  -Target prod    ($($presets.prod))
  -BaseUrl https://….up.railway.app   (Railway: Settings del servicio → Networking → Public Domain)
"@
  exit 1
}

$BaseUrl = $BaseUrl.Trim().TrimEnd('/')
Write-Host "Folio → Spring @ $BaseUrl (device=$Device)"

flutter run -d $Device `
  --dart-define=FOLIO_BACKEND_MODE=spring `
  --dart-define=FOLIO_BACKEND_BASE_URL=$BaseUrl
