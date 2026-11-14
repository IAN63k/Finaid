# Arquitectura

Finaid sigue una arquitectura por capas con el dominio en el centro. La regla es
simple: **todo lo que depende de la plataforma vive en los bordes**, y el dominio
(parsers, categorizador, insights, casos de uso) es Dart puro y se prueba sin Flutter.

```
┌──────────────────────────────────────────────────────────────────┐
│ presentation (Flutter widgets)                                   │
│   HomeShell · Dashboard · Transactions · Insights · Settings     │
├──────────────────────────────────────────────────────────────────┤
│ application (Riverpod)                                           │
│   providers.dart · IngestionService (ciclo de vida, drenaje)     │
├──────────────────────────────────────────────────────────────────┤
│ domain (Dart puro)                                               │
│   entities · parsing · categorization · insights · usecases      │
│   ports: NotificationSource, *Repository                         │
├──────────────────────────────────────────────────────────────────┤
│ infrastructure                                                   │
│   sqflite repos · AndroidNotificationSource · DeepLinkSource     │
│   AppSettingsStore (SharedPreferences)                           │
├──────────────────────────────────────────────────────────────────┤
│ plataforma                                                       │
│   Android: Kotlin NotificationListenerService + SQLite nativo    │
│   iOS (futuro): Atajos → finaid://ingest                         │
└──────────────────────────────────────────────────────────────────┘
```

## Flujo de una notificación

1. **Captura (Android, Kotlin).** `FinaidNotificationListenerService` recibe todas las
   notificaciones del sistema. Si el package está en la lista permitida (bancos + apps
   de SMS, sincronizada desde Flutter), extrae título y cuerpo (`EXTRA_BIG_TEXT`,
   `EXTRA_TEXT`, `EXTRA_TEXT_LINES`), descarta resúmenes de grupo y notificaciones
   persistentes, y guarda una fila en `finaid_native.db` con una `dedupe_key`
   (`package|id|postTime|hash`). Si Flutter está escuchando, además la emite por el
   `EventChannel`.

   El servicio vive aunque la app esté cerrada, así que nada se pierde: lo que llegue
   con la app muerta queda en el buffer.

2. **Entrega a Dart.** `AndroidNotificationSource` implementa el puerto
   `NotificationSource`: `stream` (vivo) y `drainPending()` (buffer). `IngestionService`
   arranca las fuentes disponibles, escucha el stream y drena el buffer al inicio y cada
   vez que la app vuelve a primer plano (`WidgetsBindingObserver`).

3. **Ingesta (`IngestNotificationUseCase`).**
   1. Si la `dedupe_key` ya existe → `duplicate`.
   2. Guarda la `RawNotification` (auditoría: siempre se puede ver el texto original).
   3. `ParserRegistry` elige el parser (por package, luego por firma en el texto) y
      devuelve `ParseOutcome`: transacción o motivo de descarte (`codigo_seguridad`,
      `rechazada`, `promocion`, `recordatorio`, `sin_monto`, `sin_verbo`…).
   4. Deduplicación semántica: mismo monto, misma ventana de 3 minutos, tipo compatible
      y comercio compatible → `duplicate` (cubre push + SMS del mismo banco).
   5. `Categorizer` decide la categoría: regla del usuario → tipo (ingreso/retiro) →
      palabras clave del comercio → palabras clave del texto → transferencia → otros.
   6. Guarda la `Transaction` y marca la notificación cruda como `parsed`.

4. **Estado y UI.** `TransactionsNotifier` recarga la lista; `monthSummaryProvider` e
   `insightsProvider` son derivados puros (`MonthSummary.from`, `InsightEngine`), así
   que cualquier cambio se refleja en todas las pantallas.

## Parsing

- `MoneyParser` entiende `$45.900,00`, `$45.900`, `$45,900`, `COP 45900`, `US$12.99`,
  y descarta fechas, horas, últimos dígitos de tarjeta y referencias.
- `KindDetector` clasifica por verbos en español normalizado (sin tildes). El orden
  importa: reembolso → ingreso → retiro → transferencia enviada → compra → pago.
- `CounterpartyExtractor` busca la contraparte tras la preposición adecuada al tipo
  (`en` para compras, `a` para envíos, `de` para ingresos, `factura` para pagos) y corta
  en delimitadores (`con tu tarjeta`, `a las`, fechas, `aprobada`, puntuación…).
  Elimina prefijos de procesadores (`PAYU*`, `DLO*`, `MERPAGO*`).
- `NoiseFilter` descarta OTP, rechazos, recordatorios, promociones y avisos de
  seguridad cuando no hay un verbo transaccional.
- Los parsers por banco (`BancolombiaParser`, `NequiParser`, `DaviPlataParser`,
  `NuParser`) solo limpian prefijos; el resto lo hace la base `SpanishBankParser`. El
  parser genérico atiende bancos desconocidos y asigna el banco por firma si la hay.

Todos los montos son `int` en unidades menores (centavos). Nunca `double`.

## Categorización

`defaultKeywordRules` se evalúa en orden (por eso `UBER EATS` precede a `UBER`), con
coincidencia por prefijo de palabra sobre la `merchantKey` normalizada. Las reglas de
usuario (`MerchantRule`) se crean al elegir *Aplicar siempre* en un movimiento y
también pueden marcar un comercio como ignorado (traspasos entre cuentas propias).

## Insights

`InsightEngine` ejecuta una lista de `InsightRule` sobre un `InsightContext` que
precalcula el mes actual, los gastos por categoría y utilidades. Cada regla es pequeña
y testeable; añadir una nueva es crear una clase y registrarla en
`InsightEngine.standard()`. Umbrales en `Thresholds`.

## Persistencia

SQLite vía `sqflite` con cuatro tablas: `raw_notifications`, `transactions`,
`merchant_rules`, `budgets`. Las preferencias ligeras (onboarding, packages
habilitados) van en SharedPreferences. En tests se usa `sqflite_common_ffi` en memoria.

## Decisiones

- **Flutter + Kotlin nativo** en vez de un plugin de terceros para el listener: control
  total sobre filtrado, buffer y deduplicación, y menos dependencias que mantener.
- **Reglas deterministas** para categorizar y recomendar: funcionan offline, son
  explicables y baratas. Un modelo (local o remoto) puede añadirse después como otro
  `Categorizer`/`InsightRule` sin tocar el resto.
- **Buffer nativo + drenaje** en lugar de arrancar un motor Flutter en segundo plano
  por cada notificación: más simple y sin consumo extra de batería. Si más adelante se
  quiere procesar al instante con la app cerrada, el punto de extensión es
  `FinaidNotificationListenerService.handle` (arrancar un `FlutterEngine` headless).

## Pendientes conocidos

- Los `applicationId` de algunas apps bancarias son estimaciones; se pueden ajustar en
  Ajustes → Fuentes sin recompilar.
- Exportar CSV, notificaciones propias ("nueva compra detectada") y widgets de pantalla
  de inicio no están en esta versión.
- El build de release usa la firma de debug hasta configurar un keystore.
