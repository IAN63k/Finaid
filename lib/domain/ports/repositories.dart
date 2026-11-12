import '../entities/merchant_rule.dart';
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

abstract class RawNotificationRepository {
  Future<bool> existsByDedupeKey(String dedupeKey);
  Future<RawNotification?> byId(String id);
  Future<void> save(RawNotification notification);
  Future<void> markProcessed(String id,
      {required String status, String? reason});
  Future<int> count();
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
