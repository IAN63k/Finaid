import '../../core/utils/date_utils.dart';
import '../entities/transaction.dart';

/// Datos precalculados que comparten todas las reglas de insights.
class InsightContext {
  InsightContext({
    required this.now,
    required List<Transaction> transactions,
    required this.budgets,
    this.expectedIncomeMinor,
    this.lastBackupAt,
  }) : all = transactions.where((t) => !t.ignored).toList(growable: false) {
    monthStart = Dates.monthStart(now);
    thisMonth = all
        .where((t) =>
            !t.occurredAt.isBefore(monthStart) &&
            t.occurredAt.isBefore(Dates.nextMonthStart(now)))
        .toList(growable: false);
    thisMonthExpenses =
        thisMonth.where((t) => t.countsAsExpense).toList(growable: false);
    thisMonthRefunds =
        thisMonth.where((t) => t.countsAsRefund).toList(growable: false);
    thisMonthIncome = thisMonth
        .where((t) => t.countsAsIncome)
        .fold(0, (acc, t) => acc + t.amountMinor);
    // Gasto neto: las devoluciones restan.
    thisMonthSpend = sum([...thisMonthExpenses, ...thisMonthRefunds]);
    thisMonthByCategory = byCategory([...thisMonthExpenses, ...thisMonthRefunds]);
  }

  final DateTime now;

  /// Movimientos no ignorados, de todos los tiempos.
  final List<Transaction> all;

  /// Presupuestos mensuales por categoría (unidades menores).
  final Map<String, int> budgets;

  /// Ingreso mensual estimado por el usuario, para cuando el banco no
  /// notifica los ingresos (unidades menores).
  final int? expectedIncomeMinor;

  /// Último respaldo creado por el usuario (`null` si nunca).
  final DateTime? lastBackupAt;

  /// Ingreso del mes: el detectado si existe, si no el estimado.
  int get effectiveIncome =>
      thisMonthIncome > 0 ? thisMonthIncome : (expectedIncomeMinor ?? 0);

  bool get incomeIsEstimated =>
      thisMonthIncome == 0 && (expectedIncomeMinor ?? 0) > 0;

  late final DateTime monthStart;
  late final List<Transaction> thisMonth;
  /// Gastos del mes (sin devoluciones), para reglas que cuentan compras.
  late final List<Transaction> thisMonthExpenses;
  late final List<Transaction> thisMonthRefunds;
  late final int thisMonthSpend;
  late final int thisMonthIncome;
  late final Map<String, int> thisMonthByCategory;

  int get dayOfMonth => now.day;
  int get daysInMonth => Dates.daysInMonth(now);

  List<Transaction> expensesInMonth(DateTime month) {
    final start = Dates.monthStart(month);
    final end = Dates.nextMonthStart(month);
    return all
        .where((t) =>
            (t.countsAsExpense || t.countsAsRefund) &&
            !t.occurredAt.isBefore(start) &&
            t.occurredAt.isBefore(end))
        .toList(growable: false);
  }

  List<Transaction> expensesSince(Duration lookback) {
    final from = now.subtract(lookback);
    return all
        .where((t) => t.countsAsExpense && t.occurredAt.isAfter(from))
        .toList(growable: false);
  }

  /// Suma el efecto sobre el gasto: las devoluciones restan.
  int sum(Iterable<Transaction> txs) =>
      txs.fold(0, (acc, t) => acc + _impact(t));

  static int _impact(Transaction t) =>
      t.countsAsRefund ? -t.amountMinor : t.amountMinor;

  Map<String, int> byCategory(Iterable<Transaction> txs) {
    final map = <String, int>{};
    for (final t in txs) {
      final v = _impact(t);
      map.update(t.categoryId, (old) => old + v, ifAbsent: () => v);
    }
    return map;
  }

  Map<String, List<Transaction>> byMerchant(Iterable<Transaction> txs) {
    final map = <String, List<Transaction>>{};
    for (final t in txs) {
      if (t.merchantKey.isEmpty) continue;
      map.putIfAbsent(t.merchantKey, () => []).add(t);
    }
    return map;
  }
}
