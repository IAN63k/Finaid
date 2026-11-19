# Changelog

Todos los cambios notables de este proyecto se documentan en este archivo.

El formato se basa en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/)
y el proyecto sigue [Versionado Semántico](https://semver.org/lang/es/).

## [Unreleased]

## [0.7.2] - 2026-11-19

### Corregido

- Activar el bloqueo decía "No se confirmó": faltaba declarar el permiso
  `USE_BIOMETRIC`, y Android rechazaba la autenticación antes de mostrar la huella. Es un
  permiso normal (se concede al instalar, sin preguntar).
- Los fallos de autenticación quedan en el log (`FinaidAuth`) y `tool/android_diag.ps1`
  los incluye.

## [0.7.1] - 2026-11-19

Primera versión instalable con todo lo de 0.7.0.

### Corregido

- El build de release fallaba: `BIOMETRIC_ERROR_NEGATIVE_BUTTON` solo existe en la
  biblioteca AndroidX, no en la API del sistema que usa Finaid (y no hace falta: no hay
  botón negativo porque el PIN es la alternativa).

## [0.7.0] - 2026-11-19

Etiqueta creada, pero el APK no llegó a publicarse (ver 0.7.1). Contenido funcional:

### Añadido

- **Bloqueo con huella, rostro o PIN**: Ajustes → Seguridad. Usa el bloqueo del propio
  teléfono (BiometricPrompt del sistema en Android 10+, confirmación de credenciales en
  versiones anteriores), sin dependencias externas. Activarlo y desactivarlo pide
  confirmar la identidad.
- La app arranca bloqueada y se vuelve a bloquear al regresar tras el tiempo elegido:
  cada vez que se sale, tras 1 minuto (por defecto) o tras 5 minutos. Volver del
  selector de archivos, de los ajustes de Android o de un permiso no la bloquea.
- La pantalla de bloqueo cubre también las páginas abiertas; con la app bloqueada no se
  muestran alertas dentro de la app y el botón atrás la manda al fondo.
- Con el bloqueo activo, los avisos de Finaid ocultan montos y comercios en la pantalla de
  bloqueo del teléfono ("Nuevo movimiento registrado").
- Si el teléfono deja de tener bloqueo de pantalla, Finaid desactiva el suyo en lugar de
  dejar al usuario por fuera de sus datos.

## [0.6.0] - 2026-11-19

### Añadido

- **Alertas de presupuesto**: cuando un gasto lleva su categoría al 80% o al 100% del
  presupuesto mensual llega un aviso destacado ("⚠️ Vas en el 85% de tu presupuesto de
  Restaurantes · te quedan $45.000 para 11 días"). Funciona con la app cerrada
  (notificación en un canal propio, "Alertas de presupuesto"), con la app abierta (aviso
  dentro de la app) y al registrar gastos a mano. No se repite mientras el presupuesto
  siga en el mismo nivel.
- El aviso de cada compra incluye cómo va el presupuesto de su categoría
  ("📊 62% del presupuesto de Restaurantes · quedan $114.000").
- Inicio → *Por categoría*: las categorías con presupuesto muestran el avance contra el
  límite, en ámbar desde el 80% y en rojo al superarlo, con lo que queda.
- Ajustes → Avisos → **Alertas de presupuesto** para activarlas o apagarlas (vienen
  activas). Siguen llegando aunque se apaguen los avisos normales de cada movimiento.

## [0.5.1] - 2026-11-19

### Corregido

- "Crear respaldo" fallaba siempre con *object is unsendable*: el trabajo enviado al
  isolate de cifrado arrastraba la pantalla. El cifrado y el descifrado ahora usan
  funciones de nivel superior que solo reciben datos, con un test que las ejecuta en un
  isolate real.
- "Restaurar" ya no filtra por tipo de archivo (Drive y Samsung no siempre reportan un
  `.json` como `application/json`). Si el archivo no es un respaldo, se avisa con un
  mensaje claro.
- El error de crear respaldo muestra un mensaje legible en vez del detalle técnico.

## [0.5.0] - 2026-11-19

### Añadido

- **Respaldo**: Ajustes → Tus datos → Respaldo y exportación. Un archivo `.json` con
  movimientos, reglas por comercio, presupuestos, ajustes y notificaciones recibidas.
  Opcionalmente cifrado con contraseña (AES-256-GCM, clave derivada con
  PBKDF2-HMAC-SHA256 de 100.000 iteraciones). Se guarda donde el usuario elija (Drive,
  Descargas, computador) con el selector de archivos de Android, sin pedir permisos de
  almacenamiento.
- **Restaurar**: combina el respaldo con los datos actuales; restaurar dos veces no
  duplica. En conflictos de ajustes y presupuestos gana lo que ya está en el teléfono.
  Detecta contraseña incorrecta, archivos alterados y respaldos de versiones futuras.
- **Exportar a Excel (CSV)**: del mes seleccionado o de todo; separador `;`, BOM UTF-8,
  gastos en negativo y protección contra inyección de fórmulas.
- Recordatorio en Consejos cuando hay 15 o más movimientos y no hay respaldo, o el último
  tiene más de 30 días.

## [0.4.0] - 2026-11-19

### Añadido

- Separador de miles automático en los campos de dinero (registro manual, presupuestos e
  ingreso mensual): `1500000` se ve como `1.500.000` mientras se escribe. El cursor no
  salta y borrar un punto borra el dígito anterior.
- Botón atrás del teléfono: desde Movimientos, Consejos o Ajustes vuelve a Inicio; en
  Inicio pregunta "¿Salir de Finaid?" antes de cerrar.

### Cambiado

- Scripts de ADB: eligen un solo dispositivo cuando el celular aparece dos veces por
  Wi-Fi (`tool/adb_common.ps1`).

## [0.3.2] - 2026-11-19

### Cambiado

- Primera versión firmada con la llave estable del repositorio. Hay que desinstalar la
  versión anterior una última vez; desde aquí las actualizaciones se instalan encima y
  conservan el historial.

## [0.3.1] - 2026-11-19

Primera versión instalable con todo lo de 0.3.0.

### Corregido

- El build de release fallaba al aplicar el bloque de firma: en los scripts Kotlin de
  Gradle `java.util` resolvía a la extensión `java`. El bloque ahora lee
  `key.properties` sin depender de ese paquete.

## [0.3.0] - 2026-11-19

Etiqueta creada, pero el APK no llegó a publicarse (ver 0.3.1). Contenido funcional:

Las compras de BBVA no se registraban: Finaid escuchaba un package equivocado
(`com.bbva.nxt_colombia`) y el real es `co.com.bbva.mb`. El parser ya entendía el
texto ("realizaste una compra por $26,190.00 en Mp*agc tecnologia…").

### Corregido

- Package real de BBVA Colombia (`co.com.bbva.mb`).
- Los packages que se agregan a la lista en una actualización se activan solos en
  instalaciones existentes, salvo que el usuario los haya desactivado.
- El contador "Movimientos" del inicio incluye ingresos, no solo gastos.

### Añadido

- Detección automática de apps bancarias por package o nombre visible (BBVA, Bancolombia,
  Itaú, AV Villas, Caja Social, "banco", "bank"…): se escuchan sin configurar nada,
  salvo que el usuario las apague. Las desactivaciones explícitas se respetan.
- **Probar captura**: Finaid publica una notificación de prueba y verifica el camino
  completo (servicio nativo → parser) sin crear movimientos.
- **Copiar diagnóstico**: reporte al portapapeles con estado del servicio, fuentes,
  apps que han notificado y últimas notificaciones recibidas.
- Logo de Finaid: ícono adaptativo con versión monocromática (íconos temáticos de One UI),
  splash, ícono de los avisos y marca en la app. Archivos en `docs/brand/`.
- Herramientas de desarrollo: `tool/android_diag.ps1` (diagnóstico por ADB),
  `tool/android_install_latest.ps1` (instala el último release), `tool/setup_signing.ps1`
  (firma estable) y guía `docs/DESARROLLO.md` con ADB por Wi-Fi.
- El workflow de release firma con la llave del repositorio si existen los secretos;
  si no, con una llave efímera, aplicando siempre el mismo bloque de firma.

## [0.2.1] - 2026-11-17

Primera notificación real de Nequi capturada en el S26 Ultra pero descartada por el
parser: "KAROL CASTANEDA te envió 50, ¡lo mejor!" no tiene símbolo de pesos ni
separador de miles.

### Corregido

- Montos sin `$` ni separador ("te envió 50", "Pagaste 12000 en …") cuando hay un verbo
  transaccional; la confianza baja un poco para marcarlos como revisables si hace falta.
- Verbos de ingreso de Nequi: "te envió", "te mandó", "metiste", "recargaste tu".
- Remitente antes del verbo ("X te envió …").

### Añadido

- Ajustes → **Notificaciones recibidas**: registro de todo lo que llegó de las apps
  activadas, con estado (registrada, ignorada y motivo, duplicada) y el texto original.
- Botón **Reprocesar ignoradas** para recuperar movimientos tras una mejora del parser.
- Ejemplo real de Nequi en el simulador.

## [0.2.0] - 2026-11-16

Captura robusta en segundo plano y registro manual. Motivado por la primera prueba real
en un Galaxy S26 Ultra, donde One UI suspendía el servicio y no se registraban pagos.

### Añadido

- Procesamiento en segundo plano: un motor Flutter sin interfaz (`backgroundMain`)
  parsea y guarda los movimientos aunque la app esté cerrada.
- Aviso de Finaid al registrar un movimiento (monto, comercio, categoría), con permiso
  `POST_NOTIFICATIONS` solicitado desde la app. Se puede desactivar en Ajustes.
- Escaneo de la bandeja de notificaciones al conectarse el servicio, al abrir la app y
  con el botón "Buscar en la bandeja".
- Tarjeta de estado en Ajustes: permiso, servicio conectado, batería sin restricciones y
  avisos; guía para Samsung One UI; botón para excluir a Finaid de la optimización de
  batería.
- Pantalla "Apps detectadas": lista de apps que notifican en el teléfono para activar la
  escucha con el package real.
- Registro manual de ingresos y gastos (botón "Registrar" en Movimientos y "+" en
  Inicio), e "Ingreso mensual estimado" para los consejos de ahorro.
- Parser: formato de BBVA con llaves Bre-B ("X recibió el valor de $… que enviaste a su
  llave"), fechas `AAAA/MM/DD`, variantes "tu envío por … fue exitoso".

### Cambiado

- El buffer nativo recuerda las claves ya entregadas para no re-procesar lo que sigue
  en la bandeja.
- Los ejemplos del simulador ya no incluyen saldos (los bancos no los envían) e
  incluyen el formato real de BBVA.

## [0.1.1] - 2026-11-14

Primera versión con APK publicado (firmado con la llave de debug, solo para pruebas).

### Corregido

- El build de release fallaba porque los archivos Gradle versionados pinaban Gradle 8.12 y
  Flutter 3.47 exige 9.3+. La capa Gradle ya no se versiona: la genera `flutter create .`
  en el CI y en la instalación local.

### Añadido

- Guía de instalación y prueba en el celular (`docs/PRUEBA_EN_CELULAR.md`).

## [0.1.0] - 2026-11-14

Etiqueta creada pero el APK no llegó a publicarse (ver 0.1.1). Contenido funcional:

### Añadido

- Lectura de notificaciones bancarias en Android mediante `NotificationListenerService`,
  con buffer nativo en SQLite y canales `MethodChannel`/`EventChannel` hacia Flutter.
- Parsers para Bancolombia, Nequi, DaviPlata y Nu, más un parser genérico en español que
  reconoce otros bancos por su firma en el texto (Davivienda, BBVA, Banco de Bogotá…).
- Filtro de ruido: códigos OTP, promociones, recordatorios, rechazos y avisos de saldo.
- Deduplicación de la misma compra recibida por push de la app y por SMS.
- Categorización de gastos por palabras clave (comercios colombianos) y reglas por
  comercio que el usuario enseña con "Aplicar siempre".
- Motor de recomendaciones local: presupuestos, categorías que se disparan, suscripciones,
  gastos hormiga, cobros dobles, proyección de cierre de mes, tasa de ahorro, fin de
  semana y gasto nocturno.
- Persistencia local en SQLite para notificaciones crudas, transacciones, reglas y
  presupuestos.
- Interfaz Material 3: inicio, movimientos (filtros, búsqueda, edición), consejos,
  ajustes y simulador de notificaciones con ejemplos de cada banco.
- Deep link `finaid://ingest` preparado para la ingesta en iOS (Atajos).
- CI con análisis y tests; release automático del APK al etiquetar `v*`.

[Unreleased]: https://github.com/IAN63k/Finaid/compare/v0.7.2...HEAD
[0.7.2]: https://github.com/IAN63k/Finaid/compare/v0.7.1...v0.7.2
[0.7.1]: https://github.com/IAN63k/Finaid/compare/v0.7.0...v0.7.1
[0.7.0]: https://github.com/IAN63k/Finaid/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/IAN63k/Finaid/compare/v0.5.1...v0.6.0
[0.5.1]: https://github.com/IAN63k/Finaid/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/IAN63k/Finaid/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/IAN63k/Finaid/compare/v0.3.2...v0.4.0
[0.3.2]: https://github.com/IAN63k/Finaid/compare/v0.3.1...v0.3.2
[0.3.1]: https://github.com/IAN63k/Finaid/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/IAN63k/Finaid/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/IAN63k/Finaid/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/IAN63k/Finaid/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/IAN63k/Finaid/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/IAN63k/Finaid/releases/tag/v0.1.0
