<#
.SYNOPSIS
  Descarga el APK de un release de GitHub y lo instala en el celular conectado por ADB.

.DESCRIPTION
  Sin -Tag instala el último release. Con la firma estable configurada
  (tool/setup_signing.ps1) la actualización conserva el historial; sin ella,
  Android rechaza el APK nuevo y hay que desinstalar primero.

.EXAMPLE
  pwsh tool/android_install_latest.ps1
.EXAMPLE
  pwsh tool/android_install_latest.ps1 -Tag v0.3.0
#>
param(
    [string]$Tag,
    [string]$Repo = "IAN63k/Finaid",
    # Serial de adb; por defecto $env:ANDROID_SERIAL o el celular conectado por Wi-Fi.
    [string]$Serial = $env:ANDROID_SERIAL
)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "adb_common.ps1")

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "Falta 'gh' (GitHub CLI) en el PATH. Ver docs/DESARROLLO.md" -ForegroundColor Red
    exit 1
}
Initialize-Adb $Serial | Out-Null

$dir = Join-Path ([IO.Path]::GetTempPath()) "finaid-apk"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
Get-ChildItem -Path $dir -Filter *.apk | Remove-Item -Force

$ghArgs = @("release", "download")
if ($Tag) { $ghArgs += $Tag }
$ghArgs += @("--repo", $Repo, "--pattern", "*.apk", "--dir", $dir)
& gh @ghArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$apk = Get-ChildItem -Path $dir -Filter *.apk | Select-Object -First 1
if (-not $apk) { Write-Host "No se descargó ningún APK." -ForegroundColor Red; exit 1 }
Write-Host "Instalando $($apk.Name)..."
adb install -r $apk.FullName
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "La instalación falló. Si el error es INSTALL_FAILED_UPDATE_INCOMPATIBLE, la firma cambió:" -ForegroundColor Yellow
    Write-Host "  adb uninstall co.finaid    (borra el historial local)"
    Write-Host "y vuelve a correr este script. Para evitarlo en adelante: tool/setup_signing.ps1"
    exit 1
}
Write-Host "Listo." -ForegroundColor Green
