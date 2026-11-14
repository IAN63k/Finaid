# Changelog

Todos los cambios notables de este proyecto se documentan en este archivo.

El formato se basa en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/)
y el proyecto sigue [Versionado Semántico](https://semver.org/lang/es/).

## [Unreleased]

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

[Unreleased]: https://github.com/IAN63k/Finaid/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/IAN63k/Finaid/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/IAN63k/Finaid/releases/tag/v0.1.0
