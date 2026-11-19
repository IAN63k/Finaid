import '../../core/utils/date_utils.dart';
import '../entities/transaction.dart';

/// Totales de un mes.
class MonthPoint {
  const MonthPoint({
    required this.month,
    required this.expensesMinor,
    required this.incomeMinor,
    required this.expenseCount,
    required this.isCurrent,
  });

  /// Primer día del mes.
  final DateTime month;
  final int expensesMinor;
  final int incomeMinor;
  final int expenseCount;

  /// Mes en curso (datos parciales).
  final bool isCurrent;

  int get balanceMinor => incomeMinor - expensesMinor;
}

/// Gasto por mes de los últimos N meses (opcionalmente de una categoría), con
/// promedio, mes más alto y proyección del mes en curso.
class MonthlyTrends {
  const MonthlyTrends({
    required this.points,
    required this.averageMinor,
    required this.highest,
    required this.projectionMinor,
    required this.closedMonthsWithData,
  });

  /// Del más antiguo al más reciente; el último es el mes en curso.
  final List<MonthPoint> points;

  /// Promedio de los meses cerrados desde el primer mes con datos (los meses
  /// anteriores a empezar a usar Finaid no cuentan como "cero").
  final int averageMinor;

  /// Mes cerrado con más gasto (`null` si no hay meses cerrados con datos).
  final MonthPoint? highest;

  /// Gasto proyectado del mes en curso al ritmo actual.
  final int projectionMinor;

  /// Meses cerrados que entran en el promedio.
  final int closedMonthsWithData;

  MonthPoint get current => points.last;

  /// Proyección del mes en curso frente al promedio (0,12 = 12% más).
  double? get projectionVsAverage => averageMinor <= 0
      ? null
      : (projectionMinor - averageMinor) / averageMinor;

  static MonthlyTrends compute(
    Iterable<Transaction> transactions, {
    required DateTime now,
    int months = 6,
    String? categoryId,
  }) {
    final current = Dates.monthStart(now);
    final first = Dates.addMonths(current, -(months - 1));
    final expenses = <DateTime, int>{};
    final income = <DateTime, int>{};
    final counts = <DateTime, int>{};
    DateTime? firstData;

    for (final t in transactions) {
      if (t.ignored) continue;
      if (categoryId != null && t.categoryId != categoryId) continue;
      final m = Dates.monthStart(t.occurredAt);
      if (t.countsAsExpense) {
        if (firstData == null || m.isBefore(firstData)) firstData = m;
        if (m.isBefore(first) || m.isAfter(current)) continue;
        expenses[m] = (expenses[m] ?? 0) + t.amountMinor;
        counts[m] = (counts[m] ?? 0) + 1;
      } else if (t.countsAsIncome) {
        if (m.isBefore(first) || m.isAfter(current)) continue;
        income[m] = (income[m] ?? 0) + t.amountMinor;
      }
    }

    final points = List<MonthPoint>.generate(months, (i) {
      final m = Dates.addMonths(first, i);
      return MonthPoint(
        month: m,
        expensesMinor: expenses[m] ?? 0,
        incomeMinor: income[m] ?? 0,
        expenseCount: counts[m] ?? 0,
        isCurrent: Dates.sameMonth(m, current),
      );
    });

    final dataStart = firstData;
    final closedList = points
        .where((p) =>
            !p.isCurrent && dataStart != null && !p.month.isBefore(dataStart))
        .toList();
    final average = closedList.isEmpty
        ? 0
        : (closedList.fold<int>(0, (a, p) => a + p.expensesMinor) /
                closedList.length)
            .round();
    MonthPoint? highest;
    for (final p in closedList) {
      if (highest == null || p.expensesMinor > highest.expensesMinor) highest = p;
    }

    final spent = points.last.expensesMinor;
    final projection = now.day <= 0
        ? spent
        : (spent / now.day * Dates.daysInMonth(now)).round();

    return MonthlyTrends(
      points: points,
      averageMinor: average,
      highest: highest == null || highest.expensesMinor == 0 ? null : highest,
      projectionMinor: projection,
      closedMonthsWithData: closedList.length,
    );
  }
}

/// Gasto de una categoría en lo que va del mes frente al promedio de los meses
/// anteriores **a la misma altura del mes** (comparación justa a mitad de mes).
class CategoryChange {
  const CategoryChange({
    required this.categoryId,
    required this.currentMinor,
    required this.averageMinor,
  });

  final String categoryId;
  final int currentMinor;
  final int averageMinor;

  int get differenceMinor => currentMinor - averageMinor;

  /// `null` si no hay historia con qué comparar.
  double? get ratio =>
      averageMinor <= 0 ? null : differenceMinor / averageMinor;

  /// Categorías que más cambiaron (por diferencia absoluta), descartando
  /// montos pequeños.
  static List<CategoryChange> compute(
    Iterable<Transaction> transactions, {
    required DateTime now,
    int lookbackMonths = 3,
    int minimumMinor = 20000 * 100,
  }) {
    final current = Dates.monthStart(now);
    final previous = [
      for (var i = 1; i <= lookbackMonths; i++) Dates.addMonths(current, -i),
    ];
    final cutoffDay = now.day;
    final currentByCat = <String, int>{};
    final previousByCat = <String, int>{};
    final monthsWithData = <DateTime>{};

    for (final t in transactions) {
      if (!t.countsAsExpense) continue;
      final m = Dates.monthStart(t.occurredAt);
      if (Dates.sameMonth(m, current)) {
        currentByCat[t.categoryId] =
            (currentByCat[t.categoryId] ?? 0) + t.amountMinor;
      } else if (previous.any((p) => Dates.sameMonth(p, m))) {
        monthsWithData.add(m);
        if (t.occurredAt.day <= cutoffDay) {
          previousByCat[t.categoryId] =
              (previousByCat[t.categoryId] ?? 0) + t.amountMinor;
        }
      }
    }
    final divisor = monthsWithData.isEmpty ? 1 : monthsWithData.length;
    final ids = {...currentByCat.keys, ...previousByCat.keys};
    final out = [
      for (final id in ids)
        CategoryChange(
          categoryId: id,
          currentMinor: currentByCat[id] ?? 0,
          averageMinor: monthsWithData.isEmpty
              ? 0
              : ((previousByCat[id] ?? 0) / divisor).round(),
        ),
    ]
        .where((c) =>
            (c.currentMinor >= minimumMinor || c.averageMinor >= minimumMinor))
        .toList()
      ..sort((a, b) =>
          b.differenceMinor.abs().compareTo(a.differenceMinor.abs()));
    return out;
  }
}
