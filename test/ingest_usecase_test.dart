import 'package:finaid/domain/categorization/categorizer.dart';
import 'package:finaid/domain/entities/merchant_rule.dart';
import 'package:finaid/domain/entities/raw_notification.dart';
import 'package:finaid/domain/entities/transaction.dart';
import 'package:finaid/domain/parsing/parser_registry.dart';
import 'package:finaid/domain/usecases/edit_transaction.dart';
import 'package:finaid/domain/usecases/ingest_notification.dart';
import 'package:finaid/infrastructure/memory/in_memory_repositories.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fixtures.dart';

void main() {
  late InMemoryTransactionRepository transactions;
  late InMemoryRawNotificationRepository raws;
  late InMemoryMerchantRuleRepository rules;
  late IngestNotificationUseCase ingest;

  setUp(() {
    transactions = InMemoryTransactionRepository();
    raws = InMemoryRawNotificationRepository();
    rules = InMemoryMerchantRuleRepository();
    ingest = IngestNotificationUseCase(
      rawNotifications: raws,
      transactions: transactions,
      merchantRules: rules,
      registry: ParserRegistry.standard(),
      categorizer: Categorizer.standard(),
    );
  });

  test('crea la transacción categorizada', () async {
    final result = await ingest(raw(
      package: Samples.bancolombiaPackage,
      text: Samples.bancolombiaCompra,
    ));
    expect(result.status, IngestStatus.ingested);
    final t = result.transaction!;
    expect(t.categoryId, 'mercado');
    expect(t.categorySource, CategorySource.keywordRule);
    expect(t.merchantKey, 'EXITO CALLE 80');
    expect((await transactions.all()).length, 1);
    expect(raws.status[t.rawNotificationId]!.status, 'parsed');
  });

  test('la misma notificación no se procesa dos veces', () async {
    final n = raw(
      package: Samples.nequiPackage,
      text: Samples.nequiCompra,
      dedupeKey: 'same-key',
    );
    final again = RawNotification(
      id: 'other-id',
      sourcePackage: n.sourcePackage,
      text: n.text,
      postedAt: n.postedAt,
      channel: n.channel,
      dedupeKey: 'same-key',
    );
    expect((await ingest(n)).status, IngestStatus.ingested);
    final second = await ingest(again);
    expect(second.status, IngestStatus.duplicate);
    expect(second.reason, 'notificacion_repetida');
    expect((await transactions.all()).length, 1);
  });

  test('push de la app y SMS del mismo banco cuentan una sola vez', () async {
    final push = await ingest(raw(
      package: Samples.bancolombiaPackage,
      text: Samples.bancolombiaCompra,
      postedAt: DateTime(2026, 11, 12, 14, 33, 20),
    ));
    final sms = await ingest(raw(
      package: Samples.smsPackage,
      title: 'Bancolombia',
      text: Samples.bancolombiaCompra,
      postedAt: DateTime(2026, 11, 12, 14, 34, 5),
      channel: NotificationChannel.sms,
    ));
    expect(push.status, IngestStatus.ingested);
    expect(sms.status, IngestStatus.duplicate);
    expect(sms.reason, 'movimiento_repetido');
    expect((await transactions.all()).length, 1);
  });

  test('los códigos de seguridad se ignoran y quedan trazados', () async {
    final n = raw(
      package: Samples.smsPackage,
      title: 'Bancolombia',
      text: Samples.bancolombiaOtp,
    );
    final result = await ingest(n);
    expect(result.status, IngestStatus.ignored);
    expect(result.reason, 'codigo_seguridad');
    expect(raws.status[n.id]!.status, 'ignored');
    expect(await transactions.all(), isEmpty);
  });

  test('aplica la regla del usuario por comercio', () async {
    await rules.upsert(MerchantRule(
      id: 'r1',
      merchantKey: 'RAPPI',
      categoryId: 'compras',
      ignore: true,
      createdAt: DateTime(2026),
    ));
    final t = (await ingest(raw(
      package: Samples.nequiPackage,
      text: Samples.nequiCompra,
    )))
        .transaction!;
    expect(t.categoryId, 'compras');
    expect(t.categorySource, CategorySource.merchantRule);
    expect(t.ignored, isTrue);
  });

  test('movimiento manual: ingreso registrado a mano', () async {
    final edits = EditTransactionUseCases(
        transactions: transactions, merchantRules: rules);
    final t = await edits.addManual(
      amountMinor: 3500000 * 100,
      kind: TransactionKind.deposit,
      description: 'Nómina noviembre',
      categoryId: 'ingresos',
      occurredAt: DateTime(2026, 11, 1, 9),
    );
    expect(t.bankId, 'manual');
    expect(t.merchantKey, 'NOMINA NOVIEMBRE');
    expect(t.categorySource, CategorySource.manual);
    expect(t.countsAsIncome, isTrue);
    expect((await transactions.byId(t.id))?.amountMinor, 3500000 * 100);
  });

  test('recategorizar con "aplicar siempre" crea regla y actualiza hermanos',
      () async {
    final first = (await ingest(raw(
      package: Samples.nequiPackage,
      text: Samples.nequiCompra,
      postedAt: DateTime(2026, 11, 1, 10),
    )))
        .transaction!;
    final second = (await ingest(raw(
      package: Samples.nequiPackage,
      text: Samples.nequiCompra,
      postedAt: DateTime(2026, 11, 8, 10),
    )))
        .transaction!;
    expect(first.categoryId, 'restaurantes');

    final edits = EditTransactionUseCases(
        transactions: transactions, merchantRules: rules);
    await edits.recategorize(first, 'mercado', applyToMerchant: true);

    final rule = await rules.byMerchantKey('RAPPI');
    expect(rule?.categoryId, 'mercado');
    expect((await transactions.byId(first.id))!.categorySource,
        CategorySource.manual);
    final sibling = (await transactions.byId(second.id))!;
    expect(sibling.categoryId, 'mercado');
    expect(sibling.categorySource, CategorySource.merchantRule);

    // Una nueva compra en el mismo comercio ya nace con la regla.
    final third = (await ingest(raw(
      package: Samples.nequiPackage,
      text: Samples.nequiCompra,
      postedAt: DateTime(2026, 11, 20, 10),
    )))
        .transaction!;
    expect(third.categoryId, 'mercado');
  });
}
