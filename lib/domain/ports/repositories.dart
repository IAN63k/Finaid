import '../entities/merchant_rule.dart';
import '../recurring/recurring.dart';
import '../entities/raw_notification.dart';
import '../entities/transaction.dart';

/// Puertos de persistencia. El dominio solo conoce estas interfaces; la
/// implementación (SQLite, memoria, etc.) vive en `infrastructure/`.
abstract class TransactionRepository {
  Future<List<Transaction>> all();
  Future<Transaction?> byId(String id);
  Future<List<Transaction>> byMerchantKey(String merchantKey);

  /// Movimientos con el mismo monto cerca de una fecha (para deduplicar
  /// push + SMS del mismo banco).
  Future<List<Transaction>> findSimilar({
    required int amountMinor,
    required DateTime around,
    required Duration window,
  });

  /// Inserta o reemplaza.
  Future<void> save(Transaction transaction);
  Future<void> saveAll(List<Transaction> transactions);
  Future<void> delete(String id);
}

/// Notificación cruda junto con lo que se hizo con ella.
class RawNotificationRecord {
  const RawNotificationRecord({
    required this.notification,
    required this.status,
    this.reason,
  });

  final RawNotification notification;

  /// `pending`, `parsed`, `ignored` o `duplicate`.
  final String status;
  final String? reason;
}

abstract class RawNotificationRepository {
  Future<bool> existsByDedupeKey(String dedupeKey);
  Future<RawNotification?> byId(String id);
  Future<void> save(RawNotification notification);
  Future<void> markProcessed(String id,
      {required String status, String? reason});
  Future<int> count();

  /// Últimas notificaciones recibidas, más recientes primero (diagnóstico).
  Future<List<RawNotificationRecord>> recent({int limit = 100});

  /// Notificaciones con un estado dado (p. ej. `ignored` para reprocesar).
  Future<List<RawNotification>> byStatus(String status, {int limit = 300});
}

abstract class MerchantRuleRepository {
  Future<List<MerchantRule>> all();
  Future<MerchantRule?> byMerchantKey(String merchantKey);
  Future<void> upsert(MerchantRule rule);
  Future<void> delete(String id);
}

abstract class BudgetRepository {
  /// categoryId → límite mensual en unidades menores.
  Future<Map<String, int>> all();
  Future<void> set(String categoryId, int monthlyLimitMinor);
  Future<void> remove(String categoryId);
}

/// Pagos recurrentes agregados a mano y preferencias sobre los detectados.
abstract class RecurringRepository {
  Future<List<ManualRecurring>> manual();
  Future<void> upsertManual(ManualRecurring item);
  Future<void> deleteManual(String id);

  Future<Map<String, RecurringOverride>> overrides();
  Future<void> setOverride(RecurringOverride override);
}
