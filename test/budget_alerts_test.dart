import 'package:finaid/application/budget_alert_service.dart';
import 'package:finaid/application/capture_notification_text.dart';
import 'package:finaid/domain/budgets/budget_check.dart';
import 'package:finaid/domain/entities/transaction.dart';
import 'package:finaid/infrastructure/memory/in_memory_repositories.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fixtures.dart';

void main() {
  final now = DateTime(2026, 11, 19, 12);
  const budgets = {'restaurantes': 300000 * 100};

  Transaction food(int cop, int day) => tx(
      cop: cop,
      at: DateTime(2026, 11, day, 13),
      merchant: 'RAPPI',
      category: 'restaurantes');

  group('BudgetEvaluator', () {
    test('sin presupuesto, ingresos o meses pasados no hay evaluación', () {
      expect(
        BudgetEvaluator.evaluate(
            transaction: tx(cop: 1000, at: DateTime(2026, 11, 2), category: 'mercado'),
            all: const [],
            budgets: budgets,
            now: now),
        isNull,
      );
      expect(
        BudgetEvaluator.evaluate(
            transaction: tx(
                cop: 1000,
                at: DateTime(2026, 11, 2),
                kind: TransactionKind.transferIn,
                category: 'restaurantes'),
            all: const [],
            budgets: budgets,
            now: now),
        isNull,
      );
      expect(
        BudgetEvaluator.evaluate(
            transaction: food(1000, 2).copyWith(occurredAt: DateTime(2026, 10, 2)),
            all: const [],
            budgets: budgets,
            now: now),
        isNull,
      );
    });

    test('suma solo la categoría del mes y no cuenta ignorados', () {
      final previous = [
        food(100000, 3),
        food(50000, 5),
        tx(cop: 999999, at: DateTime(2026, 11, 4), category: 'mercado'),
        food(70000, 6).copyWith(ignored: true),
        food(40000, 1).copyWith(occurredAt: DateTime(2026, 10, 30)),
      ];
      final nuevo = food(30000, 19);
      final c = BudgetEvaluator.evaluate(
          transaction: nuevo, all: [...previous, nuevo], budgets: budgets, now: now)!;
      expect(c.spentBeforeMinor, 150000 * 100);
      expect(c.spentAfterMinor, 180000 * 100);
      expect(c.level, BudgetLevel.ok);
      expect(c.crossedThreshold, isFalse);
      expect(c.remainingMinor, 120000 * 100);
      expect(c.daysLeft, 11);

      // Da lo mismo si la lista incluye o no el movimiento nuevo.
      final sinNuevo = BudgetEvaluator.evaluate(
          transaction: nuevo, all: previous, budgets: budgets, now: now)!;
      expect(sinNuevo.spentAfterMinor, c.spentAfterMinor);
    });

    test('detecta el cruce del 80% y del 100%', () {
      final warning = BudgetEvaluator.evaluate(
          transaction: food(40000, 19),
          all: [food(210000, 3)],
          budgets: budgets,
          now: now)!;
      expect(warning.previousLevel, BudgetLevel.ok);
      expect(warning.level, BudgetLevel.warning);
      expect(warning.crossedThreshold, isTrue);

      final exceeded = BudgetEvaluator.evaluate(
          transaction: food(60000, 19),
          all: [food(260000, 3)],
          budgets: budgets,
          now: now)!;
      expect(exceeded.previousLevel, BudgetLevel.warning);
      expect(exceeded.level, BudgetLevel.exceeded);
      expect(exceeded.crossedThreshold, isTrue);

      final stillOver = BudgetEvaluator.evaluate(
          transaction: food(10000, 19),
          all: [food(320000, 3)],
          budgets: budgets,
          now: now)!;
      expect(stillOver.crossedThreshold, isFalse,
          reason: 'ya estaba superado: no se repite la alerta');
    });
  });

  group('textos y avisos', () {
    BudgetCheck check(int before, int after) => BudgetCheck(
          categoryId: 'restaurantes',
          limitMinor: 300000 * 100,
          spentBeforeMinor: before * 100,
          spentAfterMinor: after * 100,
          daysLeft: 11,
        );

    test('línea del aviso según el nivel', () {
      expect(BudgetAlertText.line(check(100000, 186000)),
          '📊 62% del presupuesto de Restaurantes y domicilios · quedan \$114.000');
      expect(BudgetAlertText.line(check(200000, 255000)),
          '⚠️ 85% del presupuesto de Restaurantes y domicilios · quedan \$45.000');
      expect(BudgetAlertText.line(check(290000, 320000)),
          '🚨 Presupuesto de Restaurantes y domicilios superado por \$20.000');
    });

    test('alerta al cruzar el umbral', () {
      final t = food(55000, 19);
      final warning = BudgetAlertText.alert(check(200000, 255000), t);
      expect(warning.title,
          '⚠️ Vas en el 85% de tu presupuesto de Restaurantes y domicilios');
      expect(warning.body, 'Compra: \$55.000 en Rappi. Te quedan \$45.000 para 11 días.');

      final exceeded = BudgetAlertText.alert(check(290000, 320000), t);
      expect(exceeded.title, '🚨 Superaste tu presupuesto de Restaurantes y domicilios');
      expect(exceeded.body, contains('Llevas \$320.000 de \$300.000 este mes.'));
    });

    test('plan: una sola alerta destacada al cruzar; si no, el aviso normal', () {
      final t = food(55000, 19);
      final crossed = CaptureAlerts.plan(
          transaction: t,
          budget: check(200000, 255000),
          notifyCaptures: true,
          budgetAlerts: true);
      expect(crossed, hasLength(1));
      expect(crossed.single.isBudgetAlert, isTrue);

      final normal = CaptureAlerts.plan(
          transaction: t,
          budget: check(100000, 155000),
          notifyCaptures: true,
          budgetAlerts: true);
      expect(normal.single.isBudgetAlert, isFalse);
      expect(normal.single.body, contains('52% del presupuesto'));

      final soloAlertas = CaptureAlerts.plan(
          transaction: t,
          budget: check(200000, 255000),
          notifyCaptures: false,
          budgetAlerts: true);
      expect(soloAlertas.single.isBudgetAlert, isTrue,
          reason: 'la alerta llega aunque los avisos normales estén apagados');

      expect(
        CaptureAlerts.plan(
            transaction: t,
            budget: check(100000, 155000),
            notifyCaptures: false,
            budgetAlerts: true),
        isEmpty,
      );

      final sinAlertas = CaptureAlerts.plan(
          transaction: t,
          budget: check(200000, 255000),
          notifyCaptures: true,
          budgetAlerts: false);
      expect(sinAlertas.single.isBudgetAlert, isFalse);
      expect(sinAlertas.single.body, isNot(contains('presupuesto')));
    });
  });

  test('BudgetAlertService lee movimientos y presupuestos guardados', () async {
    final transactions = InMemoryTransactionRepository();
    final budgetRepo = InMemoryBudgetRepository();
    final service =
        BudgetAlertService(transactions: transactions, budgets: budgetRepo);

    final t = food(55000, 19);
    expect(await service.check(t, now: now), isNull, reason: 'sin presupuesto');

    await budgetRepo.set('restaurantes', 300000 * 100);
    await transactions.save(food(200000, 3));
    await transactions.save(t);
    final c = (await service.check(t, now: now))!;
    expect(c.spentAfterMinor, 255000 * 100);
    expect(c.crossedThreshold, isTrue);
  });
}
