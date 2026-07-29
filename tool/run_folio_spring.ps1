# Arranca Folio apuntando al API Spring (Railway o local).
# Uso:
#   .\tool\run_folio_spring.ps1 -BaseUrl https://TU-SERVICIO.up.railway.app
#   .\tool\run_folio_spring.ps1 -BaseUrl http://127.0.0.1:18080
#   $env:FOLIO_BACKEND_BASE_URL = 'https://…'; .\tool\run_folio_spring.ps1

param(
  [string]$BaseUrl = $env:FOLIO_BACKEND_BASE_URL,
  [string]$Device = 'windows'
)

if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
  Write-Error @"
Falta la URL del API.
  Railway: Settings del servicio → Networking → Public Domain
  Luego: .\tool\run_folio_spring.ps1 -BaseUrl https://….up.railway.app
"@
  exit 1
}

$BaseUrl = $BaseUrl.Trim().TrimEnd('/')
Write-Host "Folio → Spring @ $BaseUrl (device=$Device)"

flutter run -d $Device `
  --dart-define=FOLIO_BACKEND_MODE=spring `
  --dart-define=FOLIO_BACKEND_BASE_URL=$BaseUrl
