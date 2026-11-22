import 'dart:async';

import 'package:flutter/widgets.dart';

import '../domain/entities/raw_notification.dart';
import '../domain/entities/transaction.dart';
import '../domain/ports/notification_source.dart';
import '../domain/usecases/ingest_notification.dart';

/// Conecta las fuentes de notificaciones con el caso de uso de ingesta.
/// Escucha en vivo, recoge lo pendiente al arrancar y cada vez que la app
/// vuelve a primer plano. Cuando registra un movimiento con la app fuera de
/// pantalla, pide un aviso al sistema.
class IngestionService with WidgetsBindingObserver {
  IngestionService({
    required this.sources,
    required this.ingest,
    required this.onTransactionsChanged,
    this.onResumed,
    this.onNewTransaction,
    this.onFlaggedTransaction,
  });

  final List<NotificationSource> sources;
  final IngestNotificationUseCase ingest;
  final VoidCallback onTransactionsChanged;
  final VoidCallback? onResumed;
  /// Se llama por cada movimiento nuevo, indicando si la app está en pantalla
  /// (para decidir entre aviso del sistema o alerta dentro de la app).
  final Future<void> Function(Transaction transaction, bool inForeground)?
      onNewTransaction;

  /// Se llama cuando una compra ya registrada queda marcada para revisar
  /// (el banco avisó que una compra igual no fue exitosa).
  final Future<void> Function(Transaction transaction, bool inForeground)?
      onFlaggedTransaction;

  final List<StreamSubscription<RawNotification>> _subscriptions = [];
  final List<NotificationSource> _active = [];
  final StreamController<IngestResult> _selfTests =
      StreamController.broadcast();
  bool _started = false;
  bool _draining = false;
  bool _inForeground = true;

  /// Resultados de la autoprueba de captura ("Probar captura" en Ajustes).
  Stream<IngestResult> get selfTestResults => _selfTests.stream;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    for (final source in sources) {
      if (!await source.isAvailable()) continue;
      await source.start();
      _active.add(source);
      _subscriptions.add(source.stream.listen(handle));
    }
    await drainAll();
  }

  /// Procesa todo lo acumulado mientras la app estuvo cerrada.
  Future<int> drainAll() async {
    if (_draining) return 0;
    _draining = true;
    var ingested = 0;
    try {
      for (final source in _active) {
        final pending = await source.drainPending();
        for (final n in pending) {
          if (await handle(n, notify: false)) ingested++;
        }
      }
      if (ingested > 0) onTransactionsChanged();
    } finally {
      _draining = false;
    }
    return ingested;
  }

  Future<bool> handle(RawNotification notification, {bool notify = true}) async {
    try {
      final result = await ingest(notification);
      if (result.status == IngestStatus.selfTest) {
        _selfTests.add(result);
        return false;
      }
      if (result.isFlagged) {
        onTransactionsChanged();
        final callback = onFlaggedTransaction;
        if (callback != null) {
          await callback(result.transaction!, _inForeground);
        }
        return false;
      }
      if (result.isNewTransaction) {
        if (notify) onTransactionsChanged();
        final callback = onNewTransaction;
        if (callback != null) {
          await callback(result.transaction!, _inForeground);
        }
      }
      return result.isNewTransaction;
    } catch (e, st) {
      debugPrint('Finaid: error ingiriendo notificación: $e\n$st');
      return false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _inForeground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) {
      onResumed?.call();
      // El motor en segundo plano pudo haber guardado movimientos mientras tanto.
      onTransactionsChanged();
      drainAll();
    }
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await _selfTests.close();
    for (final s in _subscriptions) {
      await s.cancel();
    }
    for (final source in _active) {
      await source.dispose();
    }
  }
}
