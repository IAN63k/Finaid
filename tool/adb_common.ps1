<#
.SYNOPSIS
  Utilidades compartidas por los scripts de ADB (se cargan con ". $PSScriptRoot/adb_common.ps1").

.DESCRIPTION
  Por Wi-Fi el mismo celular suele aparecer dos veces en `adb devices`: una por
  `adb connect IP:PUERTO` y otra descubierta por la red (`adb-<serie>._adb-tls-connect._tcp`).
  Con dos entradas, adb responde "more than one device/emulator". Select-AdbDevice elige
  una y la deja en $env:ANDROID_SERIAL, que adb respeta en todos los comandos siguientes.
  Se prefiere la entrada descubierta por la red porque su nombre no cambia cuando cambian
  la IP o el puerto.
#>

function Find-Adb {
    $cmd = Get-Command adb -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $winget = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
    if (Test-Path $winget) {
        $found = Get-ChildItem $winget -Recurse -Filter adb.exe -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    return $null
}

function Select-AdbDevice([string]$Serial) {
    $list = @(adb devices | Select-Object -Skip 1 |
        Where-Object { $_ -match "\tdevice$" } |
        ForEach-Object { ($_ -split "\t")[0] })

    if ($Serial) {
        if ($list -contains $Serial) { return $Serial }
        throw "El dispositivo '$Serial' no está conectado. Conectados: $($list -join ', ')"
    }
    if ($list.Count -eq 0) { return $null }

    $mdns = $list | Where-Object { $_ -match '_adb-tls-connect\._tcp' } | Select-Object -First 1
    if ($mdns) { return $mdns }
    return $list[0]
}

<#
  Deja adb listo para usar: lo busca (también en la instalación de winget), elige un
  dispositivo y fija ANDROID_SERIAL. Devuelve el serial elegido o termina con un mensaje.
#>
function Initialize-Adb([string]$Serial) {
    $adbPath = Find-Adb
    if (-not $adbPath) {
        Write-Host "adb no está instalado. Instálalo con:" -ForegroundColor Red
        Write-Host "  winget install --id Google.PlatformTools"
        Write-Host "y abre una terminal nueva. Guía: docs/DESARROLLO.md"
        exit 1
    }
    $dir = Split-Path $adbPath
    if (-not (($env:Path -split ';') -contains $dir)) { $env:Path = "$dir;$env:Path" }

    $chosen = Select-AdbDevice $Serial
    if (-not $chosen) {
        Write-Host "No hay dispositivos conectados. Empareja el celular (docs/DESARROLLO.md):" -ForegroundColor Red
        Write-Host "  adb pair <IP>:<PUERTO_DE_VINCULACION>   (código de 6 dígitos)"
        Write-Host "  adb connect <IP>:<PUERTO>"
        exit 1
    }
    $env:ANDROID_SERIAL = $chosen
    Write-Host "Dispositivo: $chosen" -ForegroundColor DarkGray
    return $chosen
}
