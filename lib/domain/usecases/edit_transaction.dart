import 'package:uuid/uuid.dart';

import '../entities/category.dart';
import '../entities/merchant_rule.dart';
import '../entities/transaction.dart';
import '../ports/repositories.dart';

/// Ediciones manuales del usuario sobre un movimiento. Cuando se pide
/// "aplicar siempre", se guarda una regla por comercio y se actualizan los
/// movimientos existentes del mismo comercio.
class EditTransactionUseCases {
  EditTransactionUseCases({
    required this.transactions,
    required this.merchantRules,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final TransactionRepository transactions;
  final MerchantRuleRepository merchantRules;
  final Uuid _uuid;

  Future<void> recategorize(
    Transaction transaction,
    String categoryId, {
    bool applyToMerchant = false,
  }) async {
    final updated = transaction.copyWith(
      categoryId: categoryId,
      categorySource: CategorySource.manual,
    );
    await transactions.save(updated);

    if (!applyToMerchant || transaction.merchantKey.isEmpty) return;
    await _upsertRule(transaction.merchantKey, categoryId: categoryId);
    final siblings = await transactions.byMerchantKey(transaction.merchantKey);
    await transactions.saveAll([
      for (final s in siblings)
        if (s.id != transaction.id)
          s.copyWith(
            categoryId: categoryId,
            categorySource: CategorySource.merchantRule,
          ),
    ]);
  }

  Future<void> setIgnored(
    Transaction transaction,
    bool ignored, {
    bool applyToMerchant = false,
  }) async {
    await transactions.save(transaction.copyWith(ignored: ignored));
    if (!applyToMerchant || transaction.merchantKey.isEmpty) return;
    await _upsertRule(transaction.merchantKey, ignore: ignored);
    final siblings = await transactions.byMerchantKey(transaction.merchantKey);
    await transactions.saveAll([
      for (final s in siblings)
        if (s.id != transaction.id) s.copyWith(ignored: ignored),
    ]);
  }

  Future<void> changeKind(Transaction transaction, TransactionKind kind) async {
    var categoryId = transaction.categoryId;
    if (kind.isIncome) {
      categoryId = Categories.ingresos.id;
    } else if (categoryId == Categories.ingresos.id) {
      categoryId = Categories.otros.id;
    }
    await transactions.save(transaction.copyWith(
      kind: kind,
      categoryId: categoryId,
      confidence: 1.0,
    ));
  }

  Future<void> deleteTransaction(Transaction transaction) =>
      transactions.delete(transaction.id);

  Future<void> _upsertRule(String merchantKey,
      {String? categoryId, bool? ignore}) async {
    final existing = await merchantRules.byMerchantKey(merchantKey);
    final rule = existing == null
        ? MerchantRule(
            id: _uuid.v4(),
            merchantKey: merchantKey,
            createdAt: DateTime.now(),
            categoryId: categoryId,
            ignore: ignore ?? false,
          )
        : existing.copyWith(categoryId: categoryId, ignore: ignore);
    await merchantRules.upsert(rule);
  }
}
