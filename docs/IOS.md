# Plan para iOS

iOS no permite que una app lea las notificaciones de otra. La estrategia es la misma
que usan apps como Zentrix: una **automatización de Atajos** captura la notificación
bancaria y se la entrega a Finaid. La arquitectura ya está preparada para ello: el
dominio solo conoce `RawNotification`, y `DeepLinkNotificationSource` implementa el
puerto `NotificationSource` recibiendo URLs `finaid://ingest?...`.

## Lo que ya existe

- `DeepLinkNotificationSource` (Dart) escucha `finaid://ingest` con `app_links`, tanto
  en frío (`getInitialLink`) como en caliente (`uriLinkStream`), y construye la
  `RawNotification` con canal `iosShortcut` en iOS.
- Parsers, categorización, insights, persistencia y UI son independientes de la
  plataforma.
- En Android el mismo deep link sirve para pruebas (`adb shell am start …`).

## Pasos para activar iOS

1. **Generar el proyecto iOS** (si no se hizo ya):

   ```bash
   flutter create . --project-name finaid --org co --platforms ios --empty
   ```

2. **Registrar el esquema de URL** en `ios/Runner/Info.plist`:

   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLSchemes</key>
       <array><string>finaid</string></array>
       <key>CFBundleURLName</key>
       <string>co.finaid.ingest</string>
     </dict>
   </array>
   ```

   `app_links` se encarga del resto (no requiere código Swift adicional para esquemas
   personalizados).

3. **Crear la automatización en Atajos** (en el iPhone del usuario):

   1. Atajos → Automatización → Nueva automatización personal.
   2. Disparador: la opción de notificación de app (disponible en versiones recientes
      de iOS; si tu versión no la ofrece, usa el disparador *Transacción* de Wallet
      para Apple Pay, o el de *Mensaje* para los SMS del banco).
   3. Elegir la app bancaria (Bancolombia, Nequi, …) y marcar **Ejecutar
      inmediatamente** (sin preguntar).
   4. Acciones:
      - *Obtener texto de la entrada del atajo* (título y cuerpo de la notificación).
      - *Codificar URL* sobre ese texto.
      - *Abrir URL*:
        `finaid://ingest?app=com.nequi.MobileApp&title=Nequi&text=[Texto codificado]&ts=[Fecha actual en ms]`
        (el parámetro `ts` es opcional).
   5. Repetir para cada banco (una automatización por app).

   Finaid se abrirá un instante para registrar el movimiento. iOS no permite hacerlo
   totalmente en segundo plano; ese es el coste de la privacidad de la plataforma.

4. **Mapear bundle ids** si se quiere mostrar el nombre del banco cuando el `app` que
   envía el atajo es un bundle id de iOS: añadirlos a `BankProfile.packages` en
   `lib/domain/entities/bank.dart` (el campo acepta cualquier identificador). Si el
   atajo no envía `app`, el parser igual reconoce el banco por su firma en el texto.

5. **Pantalla de ayuda en la app**: en iOS, Ajustes muestra hoy un texto que remite a
   este documento. Conviene convertirlo en un asistente paso a paso con un botón
   *Añadir atajo* que abra un atajo compartido por iCloud preconfigurado.

## Alternativas y complementos

- **Apple Pay / Wallet**: el disparador *Transacción* de Atajos entrega monto y
  comercio de forma estructurada para pagos con Apple Pay. Se puede mapear al mismo
  deep link con `text=Compra por $<monto> en <comercio>`.
- **SMS**: el disparador *Mensaje* de Atajos funciona con remitentes concretos
  (códigos cortos del banco).
- **Extensión de compartir**: como respaldo manual, aceptar texto compartido desde
  cualquier app y pasarlo por el mismo pipeline.

## Qué no cambia

Nada del dominio ni de la persistencia. Una `RawNotification` que entra por Atajos pasa
por los mismos parsers, la misma deduplicación y las mismas reglas que una capturada en
Android.
