import 'package:finaid/domain/analytics/monthly_trends.dart';
import 'package:finaid/domain/entities/transaction.dart';
import 'package:finaid/presentation/widgets/monthly_bar_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fixtures.dart';

void main() {
  final now = DateTime(2026, 11, 15, 12);

  final history = [
    // Septiembre y octubre completos; noviembre en curso.
    tx(cop: 400000, at: DateTime(2026, 9, 5), merchant: 'EXITO', category: 'mercado'),
    tx(cop: 200000, at: DateTime(2026, 9, 20), merchant: 'RAPPI', category: 'restaurantes'),
    tx(cop: 500000, at: DateTime(2026, 10, 3), merchant: 'EXITO', category: 'mercado'),
    tx(cop: 300000, at: DateTime(2026, 10, 25), merchant: 'RAPPI', category: 'restaurantes'),
    tx(cop: 300000, at: DateTime(2026, 11, 2), merchant: 'EXITO', category: 'mercado'),
    tx(cop: 250000, at: DateTime(2026, 11, 10), merchant: 'RAPPI', category: 'restaurantes'),
    tx(cop: 3000000, at: DateTime(2026, 11, 1), kind: TransactionKind.deposit, merchant: 'NOMINA', category: 'ingresos'),
    tx(cop: 999999, at: DateTime(2026, 11, 3), merchant: 'PROPIA', category: 'transferencias', ignored: true),
  ];

  group('MonthlyTrends', () {
    test('suma por mes, del más antiguo al mes en curso', () {
      final t = MonthlyTrends.compute(history, now: now, months: 6);
      expect(t.points.length, 6);
      expect(t.points.first.month, DateTime(2026, 6));
      expect(t.points.last.month, DateTime(2026, 11));
      expect(t.points.last.isCurrent, isTrue);
      expect(t.points.map((p) => p.expensesMinor ~/ 100),
          [0, 0, 0, 600000, 800000, 550000]);
      expect(t.current.incomeMinor, 3000000 * 100);
      expect(t.current.expenseCount, 2, reason: 'el ignorado no cuenta');
    });

    test('el promedio ignora los meses antes de empezar a usar la app', () {
      final t = MonthlyTrends.compute(history, now: now, months: 6);
      expect(t.closedMonthsWithData, 2);
      expect(t.averageMinor, 700000 * 100);
      expect(t.highest?.month, DateTime(2026, 10));
      // 550.000 en 15 días de un mes de 30 → 1.100.000.
      expect(t.projectionMinor, 1100000 * 100);
      expect(t.projectionVsAverage, closeTo(0.571, 0.001));
    });

    test('filtra por categoría', () {
      final t = MonthlyTrends.compute(history,
          now: now, months: 3, categoryId: 'restaurantes');
      expect(t.points.map((p) => p.expensesMinor ~/ 100), [200000, 300000, 250000]);
      expect(t.current.incomeMinor, 0);
      expect(t.averageMinor, 250000 * 100);
    });

    test('sin historia no hay promedio ni mes más alto', () {
      final t = MonthlyTrends.compute(const [], now: now);
      expect(t.averageMinor, 0);
      expect(t.highest, isNull);
      expect(t.projectionVsAverage, isNull);
    });
  });

  group('CategoryChange', () {
    test('compara con los meses anteriores a la misma altura del mes', () {
      final changes = CategoryChange.compute(history, now: now);
      final mercado = changes.firstWhere((c) => c.categoryId == 'mercado');
      // Hasta el día 15: sep 400.000, oct 500.000 → promedio 450.000; nov 300.000.
      expect(mercado.averageMinor, 450000 * 100);
      expect(mercado.currentMinor, 300000 * 100);
      expect(mercado.ratio, closeTo(-0.333, 0.001));

      final rest = changes.firstWhere((c) => c.categoryId == 'restaurantes');
      // Sep 20 y oct 25 quedan después del día 15: promedio 0 → "nuevo".
      expect(rest.averageMinor, 0);
      expect(rest.ratio, isNull);
      expect(changes.first.categoryId, 'restaurantes',
          reason: 'ordenado por diferencia absoluta');
    });
  });

  testWidgets('el gráfico se dibuja y tocar una barra la selecciona', (tester) async {
    final t = MonthlyTrends.compute(history, now: now, months: 6);
    int? selected;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          child: MonthlyBarChart(
            points: t.points,
            averageMinor: t.averageMinor,
            selectedIndex: 5,
            onSelect: (i) => selected = i,
          ),
        ),
      ),
    ));
    expect(find.byType(MonthlyBarChart), findsOneWidget);
    // Cuarta barra (septiembre): x = 44 + slot*3.5, slot = (360-44)/6.
    final box = tester.getTopLeft(find.byType(MonthlyBarChart));
    await tester.tapAt(box + Offset(44 + (360 - 44) / 6 * 3.5, 150));
    expect(selected, 3);
  });
}
