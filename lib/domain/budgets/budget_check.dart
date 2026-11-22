import '../../core/utils/date_utils.dart';
import '../entities/transaction.dart';

enum BudgetLevel { ok, warning, exceeded }

/// Cómo queda el presupuesto de una categoría después de un gasto.
class BudgetCheck {
  const BudgetCheck({
    required this.categoryId,
    required this.limitMinor,
    required this.spentBeforeMinor,
    required this.spentAfterMinor,
    required this.daysLeft,
  });

  /// Desde qué fracción del límite se avisa.
  static const double warningRatio = 0.8;

  final String categoryId;
  final int limitMinor;

  /// Gastado en el mes en la categoría sin contar el gasto nuevo.
  final int spentBeforeMinor;

  /// Gastado en el mes en la categoría contando el gasto nuevo.
  final int spentAfterMinor;

  /// Días que quedan del mes (sin contar hoy).
  final int daysLeft;

  double get ratio => limitMinor <= 0 ? 0 : spentAfterMinor / limitMinor;

  int get remainingMinor => limitMinor - spentAfterMinor;

  BudgetLevel get level => _levelOf(spentAfterMinor);

  BudgetLevel get previousLevel => _levelOf(spentBeforeMinor);

  /// El gasto nuevo hizo pasar el presupuesto al 80% o al 100%.
  bool get crossedThreshold => level.index > previousLevel.index;

  BudgetLevel _levelOf(int spent) {
    if (limitMinor <= 0) return BudgetLevel.ok;
    if (spent >= limitMinor) return BudgetLevel.exceeded;
    if (spent >= limitMinor * warningRatio) return BudgetLevel.warning;
    return BudgetLevel.ok;
  }
}

/// Evalúa el presupuesto de la categoría de un gasto recién registrado.
class BudgetEvaluator {
  BudgetEvaluator._();

  /// `null` si el movimiento no es un gasto del mes en curso o su categoría no
  /// tiene presupuesto. [all] puede incluir o no a [transaction].
  static BudgetCheck? evaluate({
    required Transaction transaction,
    required Iterable<Transaction> all,
    required Map<String, int> budgets,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    if (!transaction.countsAsExpense) return null;
    if (!Dates.sameMonth(transaction.occurredAt, today)) return null;
    final limit = budgets[transaction.categoryId];
    if (limit == null || limit <= 0) return null;

    var spent = 0;
    var included = false;
    for (final t in all) {
      if (t.id == transaction.id) included = true;
      final current = t.id == transaction.id ? transaction : t;
      if (current.categoryId == transaction.categoryId &&
          Dates.sameMonth(current.occurredAt, transaction.occurredAt)) {
        // Las devoluciones de la categoría restan.
        spent += current.expenseImpactMinor;
      }
    }
    if (!included) spent += transaction.amountMinor;

    return BudgetCheck(
      categoryId: transaction.categoryId,
      limitMinor: limit,
      spentBeforeMinor: spent - transaction.amountMinor,
      spentAfterMinor: spent,
      daysLeft: Dates.daysInMonth(today) - today.day,
    );
  }
}
