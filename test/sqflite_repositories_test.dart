import 'package:finaid/domain/entities/merchant_rule.dart';
import 'package:finaid/domain/entities/raw_notification.dart';
import 'package:finaid/domain/entities/transaction.dart';
import 'package:finaid/infrastructure/db/app_database.dart';
import 'package:finaid/infrastructure/repositories/sqflite_repositories.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

import 'support/fixtures.dart';

void main() {
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
  });

  tearDown(() => db.close());

  test('transacciones: guardar, leer, similares y por comercio', () async {
    final repo = SqfliteTransactionRepository(db);
    final a = tx(cop: 45900, at: DateTime(2026, 11, 12, 14, 33), merchant: 'EXITO');
    final b = tx(cop: 45900, at: DateTime(2026, 11, 12, 14, 34), merchant: 'EXITO');
    final c = tx(cop: 45900, at: DateTime(2026, 11, 12, 16, 0), merchant: 'EXITO');
    await repo.saveAll([a, b, c]);

    expect((await repo.all()).map((t) => t.id), [c.id, b.id, a.id]);
    expect((await repo.byId(a.id))?.merchantKey, 'EXITO');

    final similar = await repo.findSimilar(
      amountMinor: 45900 * 100,
      around: DateTime(2026, 11, 12, 14, 33, 30),
      window: const Duration(minutes: 3),
    );
    expect(similar.map((t) => t.id).toSet(), {a.id, b.id});

    expect((await repo.byMerchantKey('EXITO')).length, 3);

    await repo.save(a.copyWith(categoryId: 'mercado', ignored: true));
    final updated = (await repo.byId(a.id))!;
    expect(updated.categoryId, 'mercado');
    expect(updated.ignored, isTrue);

    await repo.delete(a.id);
    expect((await repo.all()).length, 2);
  });

  test('notificaciones crudas: dedupe y estado', () async {
    final repo = SqfliteRawNotificationRepository(db);
    final n = RawNotification(
      id: 'n1',
      sourcePackage: 'com.nequi.MobileApp',
      title: 'Nequi',
      text: 'Compraste \$25.000 en RAPPI',
      postedAt: DateTime(2026, 11, 12, 14),
      channel: NotificationChannel.androidListener,
      dedupeKey: 'k1',
    );
    expect(await repo.existsByDedupeKey('k1'), isFalse);
    await repo.save(n);
    expect(await repo.existsByDedupeKey('k1'), isTrue);
    expect(await repo.count(), 1);
    await repo.markProcessed('n1', status: 'ignored', reason: 'sin_monto');
    final back = (await repo.byId('n1'))!;
    expect(back.fullText, 'Nequi. Compraste \$25.000 en RAPPI');
    expect(back.channel, NotificationChannel.androidListener);
  });

  test('reglas y presupuestos', () async {
    final rules = SqfliteMerchantRuleRepository(db);
    await rules.upsert(MerchantRule(
      id: 'r1',
      merchantKey: 'RAPPI',
      categoryId: 'compras',
      createdAt: DateTime(2026, 11, 1),
    ));
    await rules.upsert(MerchantRule(
      id: 'r1',
      merchantKey: 'RAPPI',
      categoryId: 'compras',
      ignore: true,
      createdAt: DateTime(2026, 11, 1),
    ));
    final rule = (await rules.byMerchantKey('RAPPI'))!;
    expect(rule.ignore, isTrue);
    expect((await rules.all()).length, 1);

    final budgets = SqfliteBudgetRepository(db);
    await budgets.set('mercado', 30000000);
    await budgets.set('mercado', 35000000);
    expect(await budgets.all(), {'mercado': 35000000});
    await budgets.remove('mercado');
    expect(await budgets.all(), isEmpty);
  });

  test('round trip de tipos', () async {
    final repo = SqfliteTransactionRepository(db);
    final t = tx(
      cop: 100,
      at: DateTime(2026, 11, 12, 14, 33),
      kind: TransactionKind.refund,
      merchant: 'X',
    ).copyWith(categorySource: CategorySource.manual, confidence: 0.6);
    await repo.save(t);
    final back = (await repo.byId(t.id))!;
    expect(back.kind, TransactionKind.refund);
    expect(back.categorySource, CategorySource.manual);
    expect(back.confidence, 0.6);
    expect(back.occurredAt, t.occurredAt);
  });
}
