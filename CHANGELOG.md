# Changelog

Todos los cambios notables de este proyecto se documentan en este archivo.

El formato se basa en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/)
y el proyecto sigue [Versionado Semántico](https://semver.org/lang/es/).

## [Unreleased]

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

[Unreleased]: https://github.com/IAN63k/Finaid/compare/v0.2.1...HEAD
[0.2.1]: https://github.com/IAN63k/Finaid/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/IAN63k/Finaid/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/IAN63k/Finaid/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/IAN63k/Finaid/releases/tag/v0.1.0
