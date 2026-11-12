# Changelog

Todos los cambios notables de este proyecto se documentan en este archivo.

El formato se basa en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/)
y el proyecto sigue [Versionado Semántico](https://semver.org/lang/es/).

## [Unreleased]

### Añadido

- Lectura de notificaciones bancarias en Android mediante `NotificationListenerService`,
  con buffer nativo en SQLite y canales `MethodChannel`/`EventChannel` hacia Flutter.
- Parsers para Bancolombia, Nequi, DaviPlata y Nu, más un parser genérico de respaldo.
- Categorización de gastos por palabras clave y reglas por comercio.
- Motor de recomendaciones (insights) local, sin envío de datos a terceros.
- Persistencia local en SQLite para transacciones, categorías y reglas.
- Deep link `finaid://ingest` preparado para la ingesta en iOS (Atajos / Share Sheet).

## [0.1.0] - Pendiente

Primera versión etiquetada planificada (`v0.1.0`). Al publicarla, mover el contenido de
`Unreleased` a esta sección con la fecha correspondiente.

[Unreleased]: https://github.com/IAN63k/Finaid/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/IAN63k/Finaid/releases/tag/v0.1.0
