<#
.SYNOPSIS
  Recolecta un diagnóstico de Finaid desde un Android conectado por ADB (USB o Wi-Fi).

.DESCRIPTION
  Guarda en diag/diag-<fecha>.txt (ignorado por git):
    - modelo y versión de Android, versión de Finaid instalada
    - si el servicio de escucha está habilitado y si Finaid está fuera de la optimización de batería
    - apps bancarias instaladas (package real)
    - notificaciones activas de apps bancarias, con título y texto exactos
    - últimas líneas de logcat de Finaid (servicio nativo, motor en segundo plano, Flutter)

  El archivo contiene texto de notificaciones bancarias: revísalo antes de compartirlo.

.EXAMPLE
  pwsh tool/android_diag.ps1
.EXAMPLE
  pwsh tool/android_diag.ps1 -LogLines 1000
#>
param(
    [string]$Out = (Join-Path $PSScriptRoot "..\diag"),
    [int]$LogLines = 400,
    [string]$Package = "co.finaid",
    # Serial de adb; por defecto $env:ANDROID_SERIAL o el celular conectado por Wi-Fi.
    [string]$Serial = $env:ANDROID_SERIAL
)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "adb_common.ps1")
Initialize-Adb $Serial | Out-Null

New-Item -ItemType Directory -Force -Path $Out | Out-Null
$file = Join-Path (Resolve-Path $Out) ("diag-{0}.txt" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
$bankPattern = 'bbva|bancolombia|todo1|nequi|davivienda|daviplata|nu\.production|nubank|bancodebogota|lulo|rappi|scotiabank|colpatria|itau|avvillas|bancoomeva|occidente|popular|falabella|cajasocial|pichincha|movii|banco|bank|messaging|mms'

function Section([string]$title) { "`n===== $title =====" }

function Get-BankNotifications {
    $lines = adb shell dumpsys notification --noredact
    $current = $null
    $include = $false
    foreach ($line in $lines) {
        if ($line -match 'NotificationRecord\(.*pkg=(\S+)') {
            $current = $Matches[1]
            $include = $current -match $bankPattern
            if ($include) { "`n-- $current" }
            continue
        }
        if ($include -and $line -match 'android\.(title|text|bigText|subText)=(.*)$') {
            "   $($Matches[1]): $($Matches[2].Trim())"
        }
        if ($include -and $line -match '^\s+(postTime|when)=(.*)$') {
            "   $($Matches[1])=$($Matches[2].Trim())"
        }
    }
}

& {
    Section "Dispositivo"
    "Modelo: " + (adb shell getprop ro.product.model)
    "Android: " + (adb shell getprop ro.build.version.release) + " (API " + (adb shell getprop ro.build.version.sdk) + ")"

    Section "Finaid instalado"
    adb shell dumpsys package $Package | Select-String -Pattern 'versionName|versionCode|lastUpdateTime' | ForEach-Object { $_.Line.Trim() }

    Section "Servicio de escucha habilitado"
    $listeners = adb shell settings get secure enabled_notification_listeners
    if ($listeners -match [regex]::Escape($Package)) { "Sí: $Package aparece en enabled_notification_listeners" }
    else { "NO: $Package no aparece en enabled_notification_listeners" }

    Section "Optimización de batería"
    $idle = adb shell dumpsys deviceidle whitelist
    if ($idle -match [regex]::Escape($Package)) { "Finaid está en la lista blanca (sin restricciones)" }
    else { "Finaid NO está en la lista blanca de batería" }
    adb shell cmd appops get $Package RUN_ANY_IN_BACKGROUND 2>$null

    Section "Apps bancarias y de mensajes instaladas"
    adb shell pm list packages --user 0 | ForEach-Object { $_ -replace '^package:', '' } | Where-Object { $_ -match $bankPattern } | Sort-Object

    Section "Notificaciones activas de apps bancarias (texto exacto)"
    Get-BankNotifications

    Section "Logcat de Finaid (últimas $LogLines líneas)"
    adb logcat -d -t $LogLines -s FinaidListener:V FinaidBackground:V flutter:V
} *>&1 | Tee-Object -FilePath $file

Write-Host ""
Write-Host "Diagnóstico guardado en: $file" -ForegroundColor Green
Write-Host "Contiene texto de notificaciones bancarias; revísalo antes de compartirlo."
