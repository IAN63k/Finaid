import '../../core/utils/date_utils.dart';
import '../entities/transaction.dart';

/// Resumen de un mes calendario. Puro: no toca base de datos.
class MonthSummary {
  const MonthSummary({
    required this.month,
    required this.transactions,
    required this.expensesMinor,
    required this.incomeMinor,
    required this.byCategory,
    required this.expenseCount,
    required this.reviewCount,
  });

  factory MonthSummary.from(List<Transaction> all, DateTime month) {
    final start = Dates.monthStart(month);
    final end = Dates.nextMonthStart(month);
    final inMonth = all
        .where((t) =>
            !t.occurredAt.isBefore(start) && t.occurredAt.isBefore(end))
        .toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    var expenses = 0;
    var income = 0;
    var expenseCount = 0;
    var review = 0;
    final byCategory = <String, int>{};
    for (final t in inMonth) {
      if (t.countsAsExpense) {
        expenses += t.amountMinor;
        expenseCount++;
        byCategory.update(t.categoryId, (v) => v + t.amountMinor,
            ifAbsent: () => t.amountMinor);
      } else if (t.countsAsIncome) {
        income += t.amountMinor;
      }
      if (t.needsReview) review++;
    }
    return MonthSummary(
      month: start,
      transactions: inMonth,
      expensesMinor: expenses,
      incomeMinor: income,
      byCategory: byCategory,
      expenseCount: expenseCount,
      reviewCount: review,
    );
  }

  final DateTime month;

  /// Movimientos del mes, más recientes primero.
  final List<Transaction> transactions;
  final int expensesMinor;
  final int incomeMinor;
  final Map<String, int> byCategory;
  final int expenseCount;
  final int reviewCount;

  int get balanceMinor => incomeMinor - expensesMinor;

  List<MapEntry<String, int>> get categoriesSorted =>
      byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  double shareOf(String categoryId) =>
      expensesMinor == 0 ? 0 : (byCategory[categoryId] ?? 0) / expensesMinor;
}
