import 'package:finaid/domain/analytics/month_summary.dart';
import 'package:finaid/domain/entities/insight.dart';
import 'package:finaid/domain/entities/transaction.dart';
import 'package:finaid/domain/insights/insight_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fixtures.dart';

void main() {
  final engine = InsightEngine.standard();
  final now = DateTime(2026, 11, 14, 12);

  final transactions = [
    // Suscripción mensual (3 cobros ~30 días).
    tx(cop: 35900, at: DateTime(2026, 9, 14, 8), merchant: 'NETFLIX COM', category: 'suscripciones'),
    tx(cop: 35900, at: DateTime(2026, 10, 14, 8), merchant: 'NETFLIX COM', category: 'suscripciones'),
    tx(cop: 35900, at: DateTime(2026, 11, 14, 8), merchant: 'NETFLIX COM', category: 'suscripciones'),
    // Mercado por encima del presupuesto.
    tx(cop: 350000, at: DateTime(2026, 11, 5, 19), merchant: 'EXITO', category: 'mercado'),
    // Posible cobro doble.
    tx(cop: 25000, at: DateTime(2026, 11, 10, 20, 0), merchant: 'RAPPI', category: 'restaurantes'),
    tx(cop: 25000, at: DateTime(2026, 11, 10, 20, 3), merchant: 'RAPPI', category: 'restaurantes'),
    // Ingreso.
    tx(cop: 1000000, at: DateTime(2026, 11, 1, 9), kind: TransactionKind.deposit, merchant: 'NOMINA', category: 'ingresos'),
    // Ignorado: no debe contar.
    tx(cop: 9000000, at: DateTime(2026, 11, 2, 9), merchant: 'CUENTA PROPIA', category: 'transferencias', ignored: true),
  ];

  test('sin movimientos solo sugiere empezar', () {
    final out = engine.generate(transactions: const [], now: now);
    expect(out.map((i) => i.kind), [InsightKind.gettingStarted]);
  });

  test('detecta presupuesto superado, cobro doble, suscripción y ahorro', () {
    final out = engine.generate(
      transactions: transactions,
      budgets: {'mercado': 300000 * 100},
      now: now,
    );
    final kinds = out.map((i) => i.kind).toSet();
    expect(kinds, contains(InsightKind.budget));
    expect(kinds, contains(InsightKind.duplicateCharge));
    expect(kinds, contains(InsightKind.subscriptions));
    expect(kinds, contains(InsightKind.savings));
    expect(kinds, contains(InsightKind.monthComparison));
    expect(kinds, isNot(contains(InsightKind.gettingStarted)));

    final budget = out.firstWhere((i) => i.kind == InsightKind.budget);
    expect(budget.severity, InsightSeverity.warning);
    expect(budget.title, contains('Superaste'));
    expect(budget.categoryId, 'mercado');

    final subs = out.firstWhere((i) => i.kind == InsightKind.subscriptions);
    expect(subs.amountMinor, 3590000);
    expect(subs.body, contains('Netflix'));

    final savings = out.firstWhere((i) => i.kind == InsightKind.savings);
    expect(savings.severity, InsightSeverity.positive);
  });

  test('las advertencias van primero', () {
    final out = engine.generate(
      transactions: transactions,
      budgets: {'mercado': 300000 * 100},
      now: now,
    );
    final firstNonWarning =
        out.indexWhere((i) => i.severity != InsightSeverity.warning);
    final lastWarning =
        out.lastIndexWhere((i) => i.severity == InsightSeverity.warning);
    expect(out.first.severity, InsightSeverity.warning);
    expect(lastWarning, lessThan(firstNonWarning));
  });

  test('usa el ingreso mensual estimado cuando el banco no notifica ingresos',
      () {
    final out = engine.generate(
      transactions: [
        tx(cop: 100000, at: DateTime(2026, 11, 5, 19), merchant: 'EXITO', category: 'mercado'),
      ],
      expectedIncomeMinor: 1000000 * 100,
      now: now,
    );
    final savings = out.firstWhere((i) => i.kind == InsightKind.savings);
    expect(savings.severity, InsightSeverity.positive);
    expect(savings.body, contains('Ingreso estimado'));
  });

  test('MonthSummary excluye ignorados y agrupa por categoría', () {
    final summary = MonthSummary.from(transactions, DateTime(2026, 11));
    expect(summary.expensesMinor, (35900 + 350000 + 25000 + 25000) * 100);
    expect(summary.incomeMinor, 1000000 * 100);
    expect(summary.byCategory['mercado'], 350000 * 100);
    expect(summary.byCategory.containsKey('transferencias'), isFalse);
    expect(summary.categoriesSorted.first.key, 'mercado');
    expect(summary.transactions.length, 6);
  });
}
