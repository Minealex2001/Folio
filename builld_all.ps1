# Script de compilación multiplataforma para Folio
$ErrorActionPreference = "Stop"

Write-Host "🚀 Iniciando proceso de compilación de Folio..." -ForegroundColor Cyan

# 1. Limpieza y preparación
Write-Host "`n🧹 Limpiando proyecto..." -ForegroundColor Yellow
flutter clean
Write-Host "📦 Obteniendo dependencias..." -ForegroundColor Yellow
flutter pub get

# Funcción para verificar éxito
function Check-Build-Success($platform) {
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Compilación para $platform completada con éxito." -ForegroundColor Green
    } else {
        Write-Warning "❌ Falló la compilación para $platform."
    }
}

# 2. Compilar para Windows
Write-Host "`n🪟 Compilando para Windows (Release)..." -ForegroundColor Cyan
flutter build windows --release
Check-Build-Success "Windows"

# 3. Compilar para Android (APK)
Write-Host "`n🤖 Compilando para Android (APK Release)..." -ForegroundColor Cyan
flutter build apk --release
Check-Build-Success "Android"

# 4. Compilar para Linux
# Nota: Esto solo funcionará si el entorno es Linux/WSL
if ($IsLinux -or $env:LSB_RELEASE -or $env:WSL_DISTRO_NAME) {
    Write-Host "`n🐧 Compilando para Linux (Release)..." -ForegroundColor Cyan
    flutter build linux --release
    Check-Build-Success "Linux"
} else {
    Write-Host "`n⚠️ Omitiendo Linux: No se detectó un entorno Linux/WSL." -ForegroundColor Magenta
    Write-Host "Pista: Para compilar Linux desde Windows, usa WSL (Ubuntu/Debian)." -ForegroundColor Gray
}

Write-Host "`n🎉 Proceso finalizado." -ForegroundColor Green
Write-Host "Los archivos resultantes están en la carpeta 'build/'." -ForegroundColor Gray
