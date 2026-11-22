import 'package:finaid/application/capture_notification_text.dart';
import 'package:finaid/domain/analytics/month_summary.dart';
import 'package:finaid/domain/budgets/budget_check.dart';
import 'package:finaid/domain/categorization/categorizer.dart';
import 'package:finaid/domain/entities/transaction.dart';
import 'package:finaid/domain/parsing/parser_registry.dart';
import 'package:finaid/domain/usecases/edit_transaction.dart';
import 'package:finaid/domain/usecases/ingest_notification.dart';
import 'package:finaid/infrastructure/memory/in_memory_repositories.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fixtures.dart';

void main() {
  final registry = ParserRegistry.standard();

  group('Parser', () {
    test('compra no exitosa: se ignora pero conserva monto, comercio y tarjeta',
        () {
      final outcome = registry.parse(raw(
        package: Samples.bbvaPackage,
        title: Samples.bbvaNoExitosaTitle,
        text: Samples.bbvaNoExitosa,
        postedAt: DateTime(2026, 11, 22, 11, 29, 40),
      ));
      expect(outcome.isTransaction, isFalse);
      expect(outcome.ignoreReason, 'rechazada');
      final r = outcome.rejected!;
      expect(r.amountMinor, 4430000);
      expect(r.merchantRaw, 'mercadoli');
      expect(r.accountHint, '2484');
      expect(r.bankId, 'bbva');
      expect(r.occurredAt, DateTime(2026, 11, 22, 11, 29));
    });

    test('compra rechazada sin monto no trae detalles', () {
      final outcome = registry.parse(raw(
        package: Samples.bancolombiaPackage,
        text: 'Bancolombia: tu compra fue rechazada. Verifica tu cupo.',
      ));
      expect(outcome.ignoreReason, 'rechazada');
      expect(outcome.rejected, isNull);
    });

    test('devolución: tipo devolución con el comercio', () {
      final t = registry
          .parse(raw(
            package: Samples.bbvaPackage,
            text: Samples.devolucionMercadoli,
          ))
          .transaction!;
      expect(t.kind, TransactionKind.refund);
      expect(t.amountMinor, 4430000);
      expect(t.merchantRaw, 'MERCADOLI');
    });
  });

  group('Ingesta', () {
    late InMemoryTransactionRepository transactions;
    late IngestNotificationUseCase ingest;

    setUp(() {
      transactions = InMemoryTransactionRepository();
      ingest = IngestNotificationUseCase(
        rawNotifications: InMemoryRawNotificationRepository(),
        transactions: transactions,
        merchantRules: InMemoryMerchantRuleRepository(),
        registry: registry,
        categorizer: Categorizer.standard(),
      );
    });

    Future<Transaction> buyMercadoli() async => (await ingest(raw(
          package: Samples.bbvaPackage,
          title: Samples.bbvaCompraTitle,
          text: Samples.bbvaCompraMercadoli,
          postedAt: DateTime(2026, 11, 22, 11, 14, 30),
        )))
            .transaction!;

    Future<IngestResult> failMercadoli() => ingest(raw(
          package: Samples.bbvaPackage,
          title: Samples.bbvaNoExitosaTitle,
          text: Samples.bbvaNoExitosa,
          postedAt: DateTime(2026, 11, 22, 11, 29, 40),
        ));

    test('compra no exitosa marca para revisar la compra igual ya registrada',
        () async {
      final bought = await buyMercadoli();
      expect(bought.needsReview, isFalse);

      final result = await failMercadoli();
      expect(result.status, IngestStatus.flagged);
      expect(result.isNewTransaction, isFalse);
      final flagged = result.transaction!;
      expect(flagged.id, bought.id);
      expect(flagged.needsReview, isTrue);
      expect(flagged.note,
          startsWith(IngestNotificationUseCase.rejectedNotePrefix));

      final all = await transactions.all();
      expect(all.length, 1, reason: 'no se crea ni se borra nada');
      expect(all.single.needsReview, isTrue);
      expect(all.single.countsAsExpense, isTrue,
          reason: 'sigue contando hasta que el usuario confirme');
    });

    test('compra no exitosa sin compra previa solo se ignora', () async {
      final result = await failMercadoli();
      expect(result.status, IngestStatus.ignored);
      expect(result.reason, 'rechazada');
      expect(await transactions.all(), isEmpty);
    });

    test('la misma compra no se marca dos veces', () async {
      await buyMercadoli();
      expect((await failMercadoli()).status, IngestStatus.flagged);
      expect((await failMercadoli()).status, IngestStatus.ignored);
    });

    test('no marca compras de otro comercio y otra tarjeta', () async {
      await ingest(raw(
        package: Samples.nequiPackage,
        text: 'Compraste \$44.300 en RAPPI con tu tarjeta Nequi *9999.',
        postedAt: DateTime(2026, 11, 22, 11, 10),
      ));
      expect((await failMercadoli()).status, IngestStatus.ignored);
    });

    test('confirmar el cobro deja de pedir revisión', () async {
      await buyMercadoli();
      final flagged = (await failMercadoli()).transaction!;
      final edits = EditTransactionUseCases(
          transactions: transactions,
          merchantRules: InMemoryMerchantRuleRepository());
      await edits.markReviewed(flagged);
      expect((await transactions.byId(flagged.id))!.needsReview, isFalse);
    });

    test('la devolución toma la categoría de la compra original', () async {
      final bought = await buyMercadoli();
      await transactions.save(bought.copyWith(categoryId: 'mercado'));

      final refund = (await ingest(raw(
        package: Samples.bbvaPackage,
        text: Samples.devolucionMercadoli,
        postedAt: DateTime(2026, 11, 25, 9),
      )))
          .transaction!;
      expect(refund.kind, TransactionKind.refund);
      expect(refund.categoryId, 'mercado');
      expect(refund.countsAsIncome, isFalse);
      expect(refund.countsAsRefund, isTrue);
      expect(refund.expenseImpactMinor, -4430000);
    });
  });

  group('Totales', () {
    final month = DateTime(2026, 11);
    final all = [
      tx(cop: 100000, at: DateTime(2026, 11, 3), merchant: 'EXITO', category: 'mercado'),
      tx(cop: 30000, at: DateTime(2026, 11, 9), merchant: 'EXITO', category: 'mercado', kind: TransactionKind.refund),
      tx(cop: 500000, at: DateTime(2026, 11, 1), merchant: 'NOMINA', category: 'ingresos', kind: TransactionKind.deposit),
    ];

    test('la devolución resta del gasto y no suma ingreso', () {
      final s = MonthSummary.from(all, month);
      expect(s.expensesMinor, 7000000);
      expect(s.incomeMinor, 50000000);
      expect(s.byCategory['mercado'], 7000000);
      expect(s.expenseCount, 1);
    });

    test('el presupuesto descuenta las devoluciones', () {
      final purchase = tx(cop: 50000, at: DateTime(2026, 11, 12), category: 'mercado');
      final check = BudgetEvaluator.evaluate(
        transaction: purchase,
        all: [...all, purchase],
        budgets: {'mercado': 20000000},
        now: DateTime(2026, 11, 12, 18),
      )!;
      expect(check.spentAfterMinor, 12000000);
      expect(check.spentBeforeMinor, 7000000);
    });
  });

  group('Avisos', () {
    test('compra por revisar pregunta si hubo cobro', () {
      final t = tx(cop: 44300, at: DateTime(2026, 11, 22, 11, 14), merchant: 'mercadoli', bank: 'bbva');
      final alert = CaptureAlerts.rejectedPurchase(t);
      expect(alert.title, contains('¿Te cobraron'));
      expect(alert.title, contains('44.300'));
      expect(alert.title, contains('Mercadoli'));
      expect(alert.body, contains('BBVA'));
      expect(alert.isBudgetAlert, isTrue);
    });

    test('la devolución se anuncia como devolución, no como ingreso', () {
      final t = tx(cop: 44300, at: DateTime(2026, 11, 25), merchant: 'MERCADOLI', kind: TransactionKind.refund);
      expect(CaptureNotificationText.title(t), startsWith('Devolución:'));
    });
  });
}
