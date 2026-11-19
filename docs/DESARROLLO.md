# Entorno de desarrollo y diagnóstico

Hay tres niveles, de menos a más montaje. Con el primero ya se puede depurar casi todo
desde el celular; el segundo permite que el asistente (o tú) vea el celular directamente
desde el PC sin cables; el tercero es compilar en local.

## 1. Desde el celular (sin instalar nada en el PC)

En Finaid → **Ajustes**:

| Herramienta | Para qué sirve |
| --- | --- |
| **Probar captura** | Finaid publica una notificación de prueba y verifica que el servicio la reciba y el parser la lea. Distingue "Android no entrega notificaciones" de "el banco usa un formato raro". No crea movimientos. |
| **Copiar diagnóstico** | Copia al portapapeles el estado del servicio, las fuentes activadas, las apps que han notificado (con su package real) y las últimas notificaciones recibidas con su estado. Pégalo en el chat o en un issue. |
| **Notificaciones recibidas** | Todo lo que llegó de las apps activadas, si se registró o por qué se ignoró, con el texto original. |
| **Apps detectadas** | Apps que han notificado en el teléfono. Las que parecen bancarias se escuchan solas. |

Regla rápida: si una notificación bancaria **no aparece** en *Notificaciones recibidas*,
el problema es la captura (package, permiso, batería). Si aparece como **Ignorada**, es
el parser: comparte ese texto.

> El diagnóstico contiene el texto de tus notificaciones bancarias. Revísalo (y cambia
> nombres o montos si quieres) antes de compartirlo.

## 2. ADB por Wi-Fi (el PC ve el celular)

Con ADB se pueden leer las notificaciones exactas del sistema, los logs del servicio de
Finaid y los packages reales de los bancos, e instalar APKs sin tocar el celular.

### Instalar ADB (una vez)

```bash
winget install --id Google.PlatformTools
```

Cierra y abre la terminal, y comprueba:

```bash
adb version
```

### Emparejar el Galaxy por Wi-Fi (una vez por red)

1. Celular y PC en la misma red Wi-Fi.
2. En el celular: Ajustes → Acerca del teléfono → Información de software → toca
   **Número de compilación** 7 veces.
3. Ajustes → **Opciones de desarrollador** → activa **Depuración inalámbrica** → entra a
   ella → **Vincular dispositivo con código de vinculación**. Aparecen una IP:puerto y un
   código de 6 dígitos.
4. En el PC (usa la IP y el puerto de *esa* ventana):

   ```bash
   adb pair 192.168.1.50:37123
   ```

   Escribe el código de 6 dígitos.
5. Conecta con la IP:puerto que muestra la pantalla principal de *Depuración inalámbrica*
   (es otro puerto):

   ```bash
   adb connect 192.168.1.50:41235
   ```

6. Verifica:

   ```bash
   adb devices
   ```

Después de reiniciar el celular solo hace falta el paso 5 (el puerto cambia).

### Scripts del proyecto

Diagnóstico completo (modelo, servicio, batería, bancos instalados, notificaciones
activas con su texto exacto y logs de Finaid). Se guarda en `diag/` (ignorado por git):

```bash
pwsh tool/android_diag.ps1
```

Instalar el último APK publicado (o uno concreto con `-Tag v0.3.0`):

```bash
pwsh tool/android_install_latest.ps1
```

Comandos sueltos útiles:

```bash
adb logcat -s FinaidListener FinaidBackground flutter
```

```bash
adb shell pm list packages | findstr /i "bbva nequi bancolombia davivienda"
```

```bash
adb shell cmd notification post -S bigtext -t "Compra Exitosa" FinaidTest "Hola, realizaste una compra por $26,190.00 en Mp*agc tecnologia con tu tarjeta BBVA *2484."
```

La última publica una notificación como la app `com.android.shell`; para que Finaid la
lea, actívala en *Apps detectadas*.

## 3. Firma estable (actualizar sin desinstalar)

Cada APK del CI se firma hoy con una llave nueva, por eso Android exige desinstalar
(y se pierde el historial) en cada versión. Para tener una llave fija:

```bash
pwsh tool/setup_signing.ps1
```

El script crea la llave en `~/.finaid/` (fuera del repo) y la sube como secretos de
GitHub (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`). El
workflow de release la usa automáticamente. Después:

1. Desinstala Finaid **una última vez** e instala el siguiente release.
2. Desde ahí, `tool/android_install_latest.ps1` o el APK de GitHub actualizan encima y
   conservan los movimientos.
3. Guarda una copia de `~/.finaid/`: sin esa llave no se puede actualizar la app
   instalada.

## 4. Compilar en local (opcional)

Requiere Flutter y Android Studio (ver README → *Puesta en marcha*). Para firmar en
local con la misma llave, crea `android/key.properties` (ignorado por git):

```properties
storeFile=C:/Users/<tu-usuario>/.finaid/finaid-release.jks
storePassword=<contenido de finaid-release.pass>
keyAlias=finaid
keyPassword=<contenido de finaid-release.pass>
```

y añade el bloque de firma al archivo generado:

```bash
cat android/release-signing.gradle.snippet >> android/app/build.gradle.kts
```
