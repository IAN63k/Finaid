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
    this.notifyCapture,
  });

  final List<NotificationSource> sources;
  final IngestNotificationUseCase ingest;
  final VoidCallback onTransactionsChanged;
  final VoidCallback? onResumed;
  final Future<void> Function(Transaction transaction)? notifyCapture;

  final List<StreamSubscription<RawNotification>> _subscriptions = [];
  final List<NotificationSource> _active = [];
  bool _started = false;
  bool _draining = false;
  bool _inForeground = true;

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
      if (result.isNewTransaction) {
        if (notify) onTransactionsChanged();
        if (!_inForeground && notifyCapture != null) {
          await notifyCapture!(result.transaction!);
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
    for (final s in _subscriptions) {
      await s.cancel();
    }
    for (final source in _active) {
      await source.dispose();
    }
  }
}
