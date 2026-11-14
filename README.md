# Finaid

Finanzas personales **automáticas y privadas**: Finaid lee las notificaciones de compra
que ya te envían tus bancos (Bancolombia, Nequi, DaviPlata, Nu, Davivienda, BBVA…),
las convierte en movimientos categorizados y te da recomendaciones sobre tu gasto.

- Sin usuario ni contraseña bancaria. Solo lee el texto de la notificación.
- Sin servidor. Todo se procesa y se guarda en tu teléfono (SQLite).
- Android primero (lectura nativa de notificaciones); la arquitectura ya contempla iOS
  vía Atajos. Ver [docs/IOS.md](docs/IOS.md).

## Qué hace

| Capa | Qué resuelve |
| --- | --- |
| **Captura** | `NotificationListenerService` en Kotlin filtra las apps bancarias y de SMS que elijas, guarda las notificaciones en un buffer nativo y las entrega a Flutter en vivo o al abrir la app. |
| **Parsing** | Parsers en Dart por banco (con un parser genérico en español) extraen monto, tipo (compra, pago, transferencia, retiro, ingreso, reembolso), comercio, tarjeta y fecha. Ignoran códigos OTP, promociones, rechazos y avisos de saldo. Deduplican push + SMS del mismo movimiento. |
| **Categorización** | Reglas por palabras clave con comercios colombianos (Éxito, Rappi, Terpel, Claro, Netflix…) más reglas que el usuario enseña ("aplicar siempre a este comercio"). |
| **Insights** | Motor determinista local: presupuesto superado o en riesgo, categoría que se dispara vs. promedio, suscripciones detectadas, gastos hormiga, cobros dobles, proyección de cierre de mes, tasa de ahorro, gasto de fin de semana y nocturno. |
| **UI** | Inicio (resumen del mes, por categoría, consejos), Movimientos (filtros, búsqueda, edición), Consejos, Ajustes (permiso, fuentes, presupuestos, reglas, simulador de notificaciones). |

## Requisitos

- Flutter **stable** (3.24 o superior) con Dart 3.5+.
- Android Studio con Android SDK (API 34+) y licencias aceptadas, o al menos
  `cmdline-tools` + `sdkmanager --licenses`.
- JDK 17 o 21 (ya tienes Java 21).

> En esta máquina Flutter y el Android SDK todavía **no están instalados**; el proyecto
> se escribió sin compilarlo. Los pasos de abajo completan el scaffold (iconos,
> `ios/`, wrapper de Gradle) y validan el código.

## Puesta en marcha

1. Instala Flutter y añádelo al `PATH`:
   <https://docs.flutter.dev/get-started/install/windows/mobile>. Instala Android
   Studio y, desde su SDK Manager, el Android SDK + Platform-Tools; luego:

   ```bash
   flutter doctor --android-licenses
   ```

2. Genera los archivos de plataforma que no se versionan: la capa Gradle de `android/`
   (`settings.gradle.kts`, `build.gradle.kts`, wrapper), los iconos y la carpeta `ios/`.
   Se dejan fuera del repo a propósito para que siempre coincidan con tu versión de
   Flutter (3.47 exige Gradle 9.3+). `flutter create` **no sobreescribe** archivos
   existentes, así que el manifest, el Kotlin y el código Dart quedan intactos:

   ```bash
   flutter create . --project-name finaid --org co --platforms android,ios --empty
   ```

3. Dependencias, análisis y tests:

   ```bash
   flutter pub get
   ```

   ```bash
   flutter analyze --no-fatal-infos
   ```

   ```bash
   flutter test
   ```

4. Ejecuta en un dispositivo o emulador Android:

   ```bash
   flutter run
   ```

5. En la app, concede **Acceso a notificaciones** (Ajustes → Abrir ajustes del sistema
   → activa Finaid). La próxima notificación bancaria aparecerá como movimiento.

### Probar sin esperar una compra real

- **Ajustes → Simular notificación**: pega el texto de un SMS o notificación y pulsa
  *Solo analizar* (no guarda) o *Registrar*. Incluye ejemplos de cada banco.
- **Deep link** (también es el camino de iOS):

  ```bash
  adb shell am start -a android.intent.action.VIEW -d "finaid://ingest?app=com.nequi.MobileApp&title=Nequi&text=Compraste%20%2425.000%20en%20RAPPI"
  ```

- **Notificación real de prueba** desde la terminal (requiere que el package esté en
  la lista de fuentes; agrégalo en Ajustes → "Agregar otra app por package"):

  ```bash
  adb shell cmd notification post -S bigtext -t "Bancolombia" FinaidTest "Bancolombia le informa Compra por \$45.900,00 en EXITO CALLE 80 a las 14:33. 12/11/2026 T.Cred *1234."
  ```

  Ese comando publica la notificación con el package `com.android.shell`.

## Estructura

```
lib/
  core/            utilidades (dinero, fechas, texto) y tema
  domain/          entidades, parsers, categorizador, insights, casos de uso, puertos
  infrastructure/  SQLite, fuentes de notificaciones (Android, deep link), ajustes
  application/     Riverpod providers e IngestionService (ciclo de vida)
  presentation/    pantallas y widgets
android/app/src/main/kotlin/co/finaid/   MainActivity + servicio de notificaciones
test/              tests unitarios (parsers, categorizador, insights, ingesta, SQLite)
docs/              ARQUITECTURA.md, IOS.md, GIT_WORKFLOW.md
```

Más detalle en [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md). Flujo de ramas, commits y
versiones en [docs/GIT_WORKFLOW.md](docs/GIT_WORKFLOW.md). Guía paso a paso para instalar
el APK o correr en modo desarrollo en tu celular:
[docs/PRUEBA_EN_CELULAR.md](docs/PRUEBA_EN_CELULAR.md).

## Añadir un banco o un formato nuevo

1. Agrega el `BankProfile` en `lib/domain/entities/bank.dart` (packages y firmas) y el
   package en `BankPackages.kt`.
2. Si el formato necesita algo especial, crea una subclase de `SpanishBankParser` en
   `lib/domain/parsing/parsers/` y regístrala en `ParserRegistry.standard()`.
3. Añade el mensaje real (anonimizado) a `test/support/fixtures.dart` y un test en
   `test/parsers_test.dart`.

## Privacidad

Finaid no se conecta a ningún banco ni a ningún servidor propio. La única salida de
datos es la que tú hagas. El permiso de acceso a notificaciones se puede revocar en
cualquier momento desde Android.
