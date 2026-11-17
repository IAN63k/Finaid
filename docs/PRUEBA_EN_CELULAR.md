# Guía: instalar y probar Finaid en tu celular Android

Hay dos caminos. El **A** no requiere instalar nada en el computador; el **B** es el de
desarrollo (hot reload, logs).

---

## A. Instalar el APK publicado en GitHub

Cada tag `vX.Y.Z` genera un APK en
<https://github.com/IAN63k/Finaid/releases>.

1. En el celular, abre la página de releases y descarga `finaid-v0.1.0.apk`.
2. Al abrir el archivo, Android pedirá permitir **instalar apps desconocidas** para el
   navegador o el gestor de archivos. Acéptalo (se puede revertir después en Ajustes →
   Apps → Acceso especial → Instalar apps desconocidas).
3. Si aparece el aviso de Play Protect ("App no verificada"), elige *Instalar de todos
   modos*. Es normal: el APK está firmado con una llave de desarrollo, no publicado en
   Play.
4. Abre Finaid. En la pantalla de bienvenida toca **Permitir acceso a notificaciones**:
   Android abre la lista de apps con acceso; activa *Finaid* y confirma.
5. Vuelve a la app y toca **Empezar**.

### Actualizar a una versión nueva

El APK de cada build se firma con una llave de debug distinta, así que Android **no
dejará instalar encima**. Desinstala Finaid y vuelve a instalar (se pierde el historial
local). Cuando configuremos un keystore propio esto dejará de pasar.

---

## B. Instalar desde el computador con Flutter (modo desarrollo)

### Requisitos en el PC (Windows)

1. **Flutter** estable: descarga el ZIP desde
   <https://docs.flutter.dev/get-started/install/windows/mobile>, descomprímelo en
   `C:\dev\flutter` (sin espacios en la ruta) y agrega `C:\dev\flutter\bin` al PATH del
   usuario.
2. **Android Studio**: instálalo y, en *More Actions → SDK Manager*, marca Android SDK
   Platform (API 35), Android SDK Build-Tools, Platform-Tools y Command-line Tools.
3. Acepta las licencias y verifica:

   ```bash
   flutter doctor --android-licenses
   ```

   ```bash
   flutter doctor
   ```

   Lo importante es que *Flutter* y *Android toolchain* salgan en verde.

### Preparar el proyecto (una sola vez)

En la carpeta del proyecto:

```bash
flutter create . --project-name finaid --org co --platforms android,ios --empty
```

```bash
flutter pub get
```

```bash
flutter test
```

### Preparar el celular

1. Ajustes → Acerca del teléfono → toca **Número de compilación** 7 veces para activar
   *Opciones de desarrollador*.
2. Opciones de desarrollador → activa **Depuración por USB**.
3. Conéctalo por cable, acepta el aviso "¿Permitir depuración USB?" en el celular y
   comprueba que aparezca:

   ```bash
   flutter devices
   ```

### Ejecutar

```bash
flutter run
```

Con `r` recargas en caliente y con `R` reinicias. Los logs del servicio nativo salen con
la etiqueta `FinaidListener`:

```bash
adb logcat -s FinaidListener
```

Para instalar un APK de release desde el PC sin hot reload:

```bash
flutter build apk --release
```

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

---

## C. Probar que funciona

### 1. Verificar el permiso

Ajustes de Finaid → la primera tarjeta debe decir **Acceso a notificaciones activo**. Si
no, toca *Abrir ajustes del sistema*, activa Finaid y luego *Volver a comprobar*.

### 2. Probar sin esperar una compra: el simulador

Ajustes → **Simular notificación**. Toca un ejemplo (Bancolombia compra, Nequi envío,
Nu suscripción…) y:

- **Solo analizar**: muestra monto, tipo, comercio, banco y confianza sin guardar nada.
- **Registrar**: crea el movimiento; aparece en Inicio y en Movimientos.

Pega también el texto de una notificación o SMS real tuyo. Si no se interpreta bien,
ese texto es justo lo que necesitamos para mejorar el parser (anonimiza montos y
nombres antes de compartirlo).

### 3. Probar con una notificación real del sistema

Con el celular conectado por USB (ruta B), este comando publica una notificación como
si fuera de otra app:

```bash
adb shell cmd notification post -S bigtext -t "Bancolombia" FinaidTest "Bancolombia le informa Compra por \$45.900,00 en EXITO CALLE 80 a las 14:33. 12/11/2026 T.Cred *1234."
```

Esa notificación sale con el package `com.android.shell`, que no está en la lista por
defecto. Agrégalo una vez en Ajustes → Fuentes → *Agregar otra app por package* →
`com.android.shell`. Al publicarla, el movimiento debe aparecer en segundos (si la app
está abierta) o al volver a abrirla (si estaba cerrada).

### 4. Probar el deep link (el camino de iOS)

```bash
adb shell am start -a android.intent.action.VIEW -d "finaid://ingest?app=com.nequi.MobileApp&title=Nequi&text=Compraste%20%2425.000%20en%20RAPPI"
```

### 5. La prueba real

Haz una compra pequeña o una transferencia con Nequi, Bancolombia, etc. La notificación
de la app bancaria (y el SMS, si lo recibes) debe convertirse en **un solo** movimiento.
Si la app no estaba abierta, el servicio la guarda y la verás al abrir Finaid.

---

## D. Qué revisar si no aparece nada

### Primero: la tarjeta "Captura de notificaciones" en Ajustes

Desde la versión 0.2.0, Ajustes muestra cuatro indicadores: **Acceso a notificaciones**,
**Servicio de escucha** (conectado o no), **Batería sin restricciones** y **Avisos de
Finaid**. Los cuatro deben estar en verde. El botón **Buscar en la bandeja** revisa las
notificaciones que todavía están en el panel de notificaciones y registra las que
falten; úsalo si ves una notificación bancaria que Finaid no tomó.

### Samsung (One UI), incluido el Galaxy S26 Ultra

One UI "duerme" las apps que no usas y desconecta el servicio de escucha. Para que la
captura funcione con Finaid cerrado:

1. Ajustes → **Batería** → **Límites de uso en segundo plano** → **Apps que nunca se
   suspenden** → agrega Finaid.
2. En esa misma pantalla, desactiva **Suspender apps que no usas** (o al menos verifica
   que Finaid no esté en "Apps suspendidas" ni "Apps en suspensión profunda").
3. Ajustes → **Aplicaciones** → Finaid → **Batería** → **Sin restricciones** (el botón
   "Permitir" de la tarjeta de Ajustes de Finaid abre el diálogo equivalente).
4. Ajustes → Aplicaciones → Finaid → **Notificaciones** → permitidas (para los avisos
   de captura).

Aunque el servicio se desconecte un rato, al abrir Finaid se revisan las notificaciones
que sigan en la bandeja, así que no se pierde lo que aún esté visible.

### Si tu banco no está en la lista o cambió de package

Ajustes → Fuentes → **Apps detectadas en este teléfono**: ahí aparecen todas las apps
que han notificado (solo nombre y conteo, nunca el contenido). Activa tu banco desde
ahí; el package real queda registrado sin tener que escribirlo.

| Síntoma | Qué mirar |
| --- | --- |
| "Servicio de escucha: desconectado" | Toca *Reconectar*. Si vuelve a desconectarse, aplica los pasos de Samsung de arriba. |
| La tarjeta de Ajustes dice "desactivado" | Falta el permiso: Ajustes de Android → Notificaciones → Acceso a notificaciones (o "Acceso especial de apps") → Finaid. |
| El permiso está activo pero no llega nada | Revisa *Apps detectadas* y activa la app del banco con su package real. Desde el PC también: `adb shell pm list packages \| grep -i banco`. |
| Llega pero se ignora | Abre Simular notificación con ese texto y pulsa *Solo analizar*: te dirá el motivo (OTP, promoción, sin monto, sin verbo). |
| Dos movimientos por una compra | Push y SMS con montos distintos o fuera de la ventana de 3 minutos; abre el movimiento duplicado → *Eliminar*. |
| Algunos fabricantes (Xiaomi, Huawei, Samsung) matan el servicio | Quita a Finaid de la optimización de batería y activa *Inicio automático* en los ajustes del fabricante. |

## E. Privacidad y permisos

Finaid pide un solo permiso: **Acceso a notificaciones**. Solo procesa las apps que
aparecen activadas en Fuentes, no tiene permiso de Internet en la versión release, y todo
queda en la base de datos local del teléfono. Se revoca desde Android en cualquier
momento.
