# Finaid en iPhone

## Qué funciona y qué no

iOS **no permite que una app lea las notificaciones de otra**, así que en iPhone Finaid no
puede capturar las notificaciones push de la app del banco como en Android. La captura se
hace con **automatizaciones de Atajos**, que le entregan el texto a Finaid con el enlace
`finaid://ingest`:

| Fuente | Cómo llega | Automático |
| --- | --- | --- |
| SMS del banco (Bancolombia, Davivienda, BBVA…) | Automatización *Mensaje* | Sí, "Ejecutar inmediatamente" |
| Pagos con Apple Pay | Automatización *Transacción* de Wallet | Sí |
| Cualquier texto (notificación copiada, correo) | Atajo en la hoja de compartir | Manual |
| Push de la app del banco | — | No es posible en iOS |

Todo lo demás es igual que en Android porque el código Dart es el mismo: parser,
categorías, presupuestos y alertas, consejos, pagos recurrentes con recordatorios,
tendencias, respaldo cifrado, exportación a CSV y bloqueo con Face ID o código.

## Arquitectura

- **Dart compartido.** El dominio no sabe de plataformas: un SMS que entra por Atajos es
  una `RawNotification` con canal `iosShortcut` que pasa por los mismos parsers.
- **`DeepLinkNotificationSource`** (Dart, `app_links`) recibe `finaid://ingest?app=…&text=…`.
  `app=ios.sms`, `ios.wallet` (Apple Pay) o `ios.share`; el banco se reconoce por su nombre
  en el texto.
- **Plugin local `packages/finaid_ios`** (Swift) implementa los mismos canales que Kotlin:
  - `co.finaid/auth`: Face ID, Touch ID o código (`LocalAuthentication`).
  - `co.finaid/documents`: selector de archivos para respaldo y CSV (`UIDocumentPicker`).
  - `co.finaid/notifications`: avisos locales (alertas de presupuesto, recordatorios de
    pagos con `UNCalendarNotificationTrigger`), permiso de avisos, datos del equipo y
    abrir Atajos.
- **`LocalNotifier`** (Dart) es la interfaz común de avisos: en Android la implementa
  `AndroidNotificationSource`; en iOS, `IosPlatformBridge`.
- **Proyecto iOS generado**, como la capa Gradle: `flutter create --platforms ios` y luego
  `tool/ios/configure.sh` (esquema `finaid://`, permiso de Face ID, nombre e ícono).

## Configurar la captura en el iPhone

En Finaid → Ajustes → **Captura con Atajos** están las recetas con un botón para copiar el
enlace. Resumen:

### SMS del banco

1. Atajos → Automatización → **+** → **Mensaje**.
2. Remitente: el número o nombre de tu banco (o "El mensaje contiene: compra").
3. **Ejecutar inmediatamente**.
4. Acción **Codificar URL** con la variable *Mensaje*.
5. Acción **Abrir URL**: `finaid://ingest?app=ios.sms&text=` + *Texto codificado en URL*.

### Apple Pay (Wallet)

1. Atajos → Automatización → **+** → **Transacción**, elige tus tarjetas.
2. **Ejecutar inmediatamente**.
3. Acción **Texto**: `Compra por [Monto] en [Comercio]`.
4. **Codificar URL** y **Abrir URL**: `finaid://ingest?app=ios.wallet&text=` + *Texto codificado*.

### Desde la hoja de compartir

Un atajo que acepte *Texto* en la hoja de compartir, con **Codificar URL** y **Abrir URL**
`finaid://ingest?app=ios.share&text=` + *Texto codificado*.

Cada automatización abre Finaid un instante para registrar el movimiento.

## Compilar e instalar

No hace falta un Mac para compilar: el CI lo hace en macOS.

- Cada push a `main` compila la versión de iPhone sin firma (job `ios-build`), así se
  detecta cualquier error de Swift.
- Cada release (`v*`) adjunta **`finaid-vX.Y.Z-ios-sin-firma.ipa`**.

Para instalarla hay que firmarla:

| Opción | Costo | Notas |
| --- | --- | --- |
| **Sideloadly** o **AltStore** con tu Apple ID | Gratis | Firma la IPA desde Windows. Con una cuenta gratuita la app vence a los 7 días y hay que volver a firmarla. |
| **Cuenta de desarrollador de Apple** + TestFlight | USD 99/año | Instalación desde TestFlight, actualizaciones normales y sin vencimiento corto. Requiere agregar al CI el certificado y el perfil como secretos. |

En el iPhone hay que activar el **Modo de desarrollador** (Ajustes → Privacidad y
seguridad) la primera vez que se instala una app firmada así.

## Próximos pasos posibles

- **App Intents** (iOS 16+): una acción de Atajos "Registrar en Finaid" que guarda el
  movimiento **sin abrir la app**. Requiere agregar el intent al target de la app en Xcode
  (o automatizarlo en `tool/ios/configure.sh`).
- **TestFlight automático** desde el workflow de release si se usa una cuenta de
  desarrollador.
