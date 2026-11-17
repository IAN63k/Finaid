import '../../domain/entities/merchant_rule.dart';
import '../../domain/entities/raw_notification.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/ports/repositories.dart';

/// Implementaciones en memoria: tests y modo demo.
class InMemoryTransactionRepository implements TransactionRepository {
  final Map<String, Transaction> _items = {};

  @override
  Future<List<Transaction>> all() async => _items.values.toList()
    ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

  @override
  Future<Transaction?> byId(String id) async => _items[id];

  @override
  Future<List<Transaction>> byMerchantKey(String merchantKey) async =>
      _items.values.where((t) => t.merchantKey == merchantKey).toList();

  @override
  Future<List<Transaction>> findSimilar({
    required int amountMinor,
    required DateTime around,
    required Duration window,
  }) async =>
      _items.values
          .where((t) =>
              t.amountMinor == amountMinor &&
              (t.occurredAt.difference(around)).abs() <= window)
          .toList();

  @override
  Future<void> save(Transaction transaction) async =>
      _items[transaction.id] = transaction;

  @override
  Future<void> saveAll(List<Transaction> transactions) async {
    for (final t in transactions) {
      _items[t.id] = t;
    }
  }

  @override
  Future<void> delete(String id) async => _items.remove(id);
}

class InMemoryRawNotificationRepository implements RawNotificationRepository {
  final Map<String, RawNotification> _items = {};
  final Map<String, ({String status, String? reason})> status = {};

  @override
  Future<bool> existsByDedupeKey(String dedupeKey) async =>
      _items.values.any((n) => n.dedupeKey == dedupeKey);

  @override
  Future<RawNotification?> byId(String id) async => _items[id];

  @override
  Future<void> save(RawNotification notification) async =>
      _items[notification.id] = notification;

  @override
  Future<void> markProcessed(String id,
          {required String status, String? reason}) async =>
      this.status[id] = (status: status, reason: reason);

  @override
  Future<int> count() async => _items.length;

  @override
  Future<List<RawNotificationRecord>> recent({int limit = 100}) async {
    final all = _items.values.toList()
      ..sort((a, b) => b.postedAt.compareTo(a.postedAt));
    return [
      for (final n in all.take(limit))
        RawNotificationRecord(
          notification: n,
          status: status[n.id]?.status ?? 'pending',
          reason: status[n.id]?.reason,
        ),
    ];
  }

  @override
  Future<List<RawNotification>> byStatus(String wanted,
          {int limit = 300}) async =>
      _items.values
          .where((n) => (status[n.id]?.status ?? 'pending') == wanted)
          .take(limit)
          .toList();
}

class InMemoryMerchantRuleRepository implements MerchantRuleRepository {
  final Map<String, MerchantRule> _byKey = {};

  @override
  Future<List<MerchantRule>> all() async => _byKey.values.toList();

  @override
  Future<MerchantRule?> byMerchantKey(String merchantKey) async =>
      _byKey[merchantKey];

  @override
  Future<void> upsert(MerchantRule rule) async =>
      _byKey[rule.merchantKey] = rule;

  @override
  Future<void> delete(String id) async =>
      _byKey.removeWhere((_, r) => r.id == id);
}

class InMemoryBudgetRepository implements BudgetRepository {
  final Map<String, int> _budgets = {};

  @override
  Future<Map<String, int>> all() async => Map.of(_budgets);

  @override
  Future<void> set(String categoryId, int monthlyLimitMinor) async =>
      _budgets[categoryId] = monthlyLimitMinor;

  @override
  Future<void> remove(String categoryId) async => _budgets.remove(categoryId);
}
