<#
.SYNOPSIS
  Crea la llave de firma de release de Finaid y la guarda como secretos de GitHub.

.DESCRIPTION
  Con una llave estable, cada APK publicado se puede instalar encima del anterior
  sin desinstalar ni perder el historial.

  - Genera un keystore PKCS12 en ~/.finaid/finaid-release.jks (fuera del repo) con
    una contraseña aleatoria guardada en ~/.finaid/finaid-release.pass.
  - Sube ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD y ANDROID_KEY_ALIAS como
    secretos del repositorio (gh secret set).

  Haz una copia de seguridad de ~/.finaid: si pierdes la llave, las siguientes
  versiones no podrán actualizar la app instalada.

  La primera instalación firmada con esta llave requiere desinstalar una última vez
  la versión anterior.

.EXAMPLE
  pwsh tool/setup_signing.ps1
#>
param(
    [string]$Dir = (Join-Path $HOME ".finaid"),
    [string]$Repo = "IAN63k/Finaid",
    [string]$Alias = "finaid"
)
$ErrorActionPreference = "Stop"

foreach ($cmd in "keytool", "gh") {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Host "Falta '$cmd' en el PATH (keytool viene con el JDK)." -ForegroundColor Red
        exit 1
    }
}

New-Item -ItemType Directory -Force -Path $Dir | Out-Null
$jks = Join-Path $Dir "finaid-release.jks"
$passFile = Join-Path $Dir "finaid-release.pass"

if (Test-Path -LiteralPath $jks) {
    Write-Host "Ya existe $jks; se reutiliza."
    if (-not (Test-Path -LiteralPath $passFile)) {
        Write-Host "Falta $passFile con la contraseña del keystore." -ForegroundColor Red
        exit 1
    }
} else {
    $chars = [char[]](48..57 + 65..90 + 97..122)
    $pass = -join (1..32 | ForEach-Object { $chars | Get-Random })
    keytool -genkeypair -noprompt -keystore $jks -storetype PKCS12 -alias $Alias `
        -keyalg RSA -keysize 2048 -validity 10000 `
        -storepass $pass -keypass $pass -dname "CN=Finaid, O=Finaid, C=CO"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    [IO.File]::WriteAllText($passFile, $pass)
    Write-Host "Keystore creado en $jks" -ForegroundColor Green
}

$pass = [IO.File]::ReadAllText($passFile).Trim()
$b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($jks))

$b64 | gh secret set ANDROID_KEYSTORE_BASE64 --repo $Repo
$pass | gh secret set ANDROID_KEYSTORE_PASSWORD --repo $Repo
$Alias | gh secret set ANDROID_KEY_ALIAS --repo $Repo

Write-Host ""
Write-Host "Secretos configurados en $Repo." -ForegroundColor Green
Write-Host "Haz una copia de seguridad de la carpeta $Dir (por ejemplo en tu gestor de contraseñas)."
Write-Host "El próximo release saldrá firmado con esta llave: desinstala Finaid una última vez antes de instalarlo."
