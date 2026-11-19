import 'dart:convert';
import 'dart:io';

import 'package:finaid/application/backup_service.dart';
import 'package:finaid/application/recurring_service.dart';
import 'package:finaid/domain/backup/backup_payload.dart';
import 'package:finaid/domain/entities/transaction.dart';
import 'package:finaid/domain/recurring/recurring.dart';
import 'package:finaid/domain/recurring/recurring_detector.dart';
import 'package:finaid/domain/recurring/reminder_planner.dart';
import 'package:finaid/infrastructure/db/app_database.dart';
import 'package:finaid/infrastructure/memory/in_memory_repositories.dart';
import 'package:finaid/infrastructure/repositories/sqflite_repositories.dart';
import 'package:finaid/infrastructure/settings/app_settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

import 'support/fixtures.dart';

void main() {
  final now = DateTime(2026, 11, 19, 12);

  Transaction netflix(DateTime at, [int cop = 35900]) =>
      tx(cop: cop, at: at, merchant: 'NETFLIX', category: 'suscripciones');

  group('RecurringDetector', () {
    test('detecta un cobro mensual y calcula el próximo', () {
      final found = RecurringDetector.detect([
        netflix(DateTime(2026, 9, 14, 8)),
        netflix(DateTime(2026, 10, 14, 8)),
        netflix(DateTime(2026, 11, 14, 8)),
      ], now: now);
      final p = found.single;
      expect(p.id, 'auto:NETFLIX');
      expect(p.name, 'Netflix');
      expect(p.amountMinor, 3590000);
      expect(p.occurrences, 3);
      expect(p.nextDueAt, DateTime(2026, 12, 14));
      expect(p.source, RecurringSource.detected);
      expect(p.daysUntil(now), 25);
    });

    test('tolera cambios de tarifa pequeños', () {
      final found = RecurringDetector.detect([
        netflix(DateTime(2026, 9, 14), 33900),
        netflix(DateTime(2026, 10, 14), 35900),
      ], now: now);
      expect(found.single.amountMinor, 3590000);
    });

    test('no confunde compras frecuentes ni cobros viejos con recurrentes', () {
      final weekly = [
        for (var d = 1; d <= 19; d += 7)
          tx(cop: 50000, at: DateTime(2026, 11, d), merchant: 'EXITO', category: 'mercado'),
      ];
      final old = [
        netflix(DateTime(2026, 6, 1)),
        netflix(DateTime(2026, 7, 1)),
      ];
      expect(RecurringDetector.detect([...weekly, ...old], now: now), isEmpty);
    });

    test('separa dos suscripciones del mismo comercio', () {
      Transaction google(DateTime at, int cop) =>
          tx(cop: cop, at: at, merchant: 'GOOGLE', category: 'suscripciones');
      final found = RecurringDetector.detect([
        google(DateTime(2026, 9, 3), 8900),
        google(DateTime(2026, 9, 10), 26900),
        google(DateTime(2026, 10, 3), 8900),
        google(DateTime(2026, 10, 10), 26900),
        google(DateTime(2026, 11, 3), 8900),
        google(DateTime(2026, 11, 10), 26900),
      ], now: now);
      expect(found.map((p) => p.amountMinor).toSet(), {890000, 2690000});
      expect(found.map((p) => p.id).toSet(), {'auto:GOOGLE', 'auto:GOOGLE#2'});
    });

    test('ignora ingresos e ignorados', () {
      final found = RecurringDetector.detect([
        tx(cop: 3500000, at: DateTime(2026, 10, 1), kind: TransactionKind.deposit, merchant: 'NOMINA'),
        tx(cop: 3500000, at: DateTime(2026, 11, 1), kind: TransactionKind.deposit, merchant: 'NOMINA'),
        netflix(DateTime(2026, 10, 14)).copyWith(ignored: true),
        netflix(DateTime(2026, 11, 14)).copyWith(ignored: true),
      ], now: now);
      expect(found, isEmpty);
    });
  });

  group('ManualRecurring', () {
    ManualRecurring rent({int day = 5, DateTime? paid}) => ManualRecurring(
          id: 'm1',
          name: 'Arriendo',
          amountMinor: 1200000 * 100,
          categoryId: 'hogar',
          dayOfMonth: day,
          createdAt: DateTime(2026, 1, 1),
          lastPaidMonth: paid,
        );

    test('próxima fecha según el día del mes y el pago registrado', () {
      expect(rent(day: 25).nextDue(now), DateTime(2026, 11, 25));
      // El 5 ya pasó hace 14 días y no se registró: sigue pendiente.
      expect(rent(day: 5).nextDue(now), DateTime(2026, 11, 5));
      // Registrado este mes: pasa al siguiente.
      expect(rent(day: 5, paid: DateTime(2026, 11)).nextDue(now), DateTime(2026, 12, 5));
      // Pasó hace más de 20 días: se asume pagado por fuera.
      expect(rent(day: 5).nextDue(DateTime(2026, 11, 28)), DateTime(2026, 12, 5));
    });

    test('día 31 en meses cortos usa el último día', () {
      expect(rent(day: 31).nextDue(DateTime(2027, 2, 2)), DateTime(2027, 2, 28));
    });
  });

  group('ReminderPlanner', () {
    final detected = RecurringPayment(
      id: 'auto:NETFLIX',
      name: 'Netflix',
      amountMinor: 3590000,
      categoryId: 'suscripciones',
      nextDueAt: DateTime(2026, 11, 22),
      source: RecurringSource.detected,
    );
    final manual = RecurringPayment(
      id: 'm1',
      name: 'Arriendo',
      amountMinor: 120000000,
      categoryId: 'hogar',
      nextDueAt: DateTime(2026, 11, 25),
      source: RecurringSource.manual,
    );

    test('avisa N días antes y, en pagos manuales, también el mismo día', () {
      final plan = ReminderPlanner.plan([detected, manual], now: now, daysBefore: 2);
      final netflixReminders = plan.where((r) => r.title.contains('Netflix')).toList();
      expect(netflixReminders.first.at, DateTime(2026, 11, 20, 9));
      expect(netflixReminders.first.title, 'En 2 días se cobra Netflix');
      expect(netflixReminders.first.body, startsWith('~\$35.900 · 📺 Suscripciones'));

      final rent = plan.where((r) => r.title.contains('Arriendo')).toList();
      expect(rent.map((r) => r.at), containsAll([DateTime(2026, 11, 23, 9), DateTime(2026, 11, 25, 9)]));
      expect(rent.firstWhere((r) => r.at.day == 25).title, 'Hoy vence Arriendo');
      expect(rent.firstWhere((r) => r.at.day == 25).body, contains('registrar el pago'));
    });

    test('cubre también el mes siguiente y salta lo que ya pasó', () {
      final plan = ReminderPlanner.plan([detected], now: now, daysBefore: 1);
      expect(plan.map((r) => r.at), [DateTime(2026, 11, 21, 9), DateTime(2026, 12, 21, 9)]);
      expect(plan.first.title, 'Mañana se cobra Netflix');

      final late = ReminderPlanner.plan([detected],
          now: DateTime(2026, 11, 21, 10), daysBefore: 1);
      expect(late.single.at, DateTime(2026, 12, 21, 9));
    });

    test('sin aviso activo no programa nada; ids estables', () {
      expect(ReminderPlanner.plan([detected.copyWith(remind: false)], now: now, daysBefore: 2),
          isEmpty);
      final a = ReminderPlanner.plan([detected], now: now, daysBefore: 2);
      final b = ReminderPlanner.plan([detected], now: now, daysBefore: 2);
      expect(a.map((r) => r.id), b.map((r) => r.id));
      expect(a.map((r) => r.id).toSet().length, a.length);
    });
  });

  group('RecurringService', () {
    late InMemoryTransactionRepository transactions;
    late InMemoryRecurringRepository recurring;
    late RecurringService service;

    setUp(() async {
      transactions = InMemoryTransactionRepository();
      recurring = InMemoryRecurringRepository();
      service = RecurringService(transactions: transactions, recurring: recurring);
      await transactions.saveAll([
        netflix(DateTime(2026, 9, 14)),
        netflix(DateTime(2026, 10, 14)),
        netflix(DateTime(2026, 11, 14)),
      ]);
    });

    test('junta detectados y manuales ordenados por fecha', () async {
      await service.saveManual(
          name: 'Arriendo', amountMinor: 120000000, categoryId: 'hogar', dayOfMonth: 25, remind: true);
      final list = await service.list(now: now);
      expect(list.map((p) => p.name), ['Arriendo', 'Netflix']);
    });

    test('descartar, deshacer y apagar el aviso', () async {
      final p = (await service.list(now: now)).single;
      await service.dismiss(p);
      expect(await service.list(now: now), isEmpty);
      await service.restore(p);
      expect((await service.list(now: now)).single.remind, isTrue);
      await service.setRemind(p, false);
      expect((await service.list(now: now)).single.remind, isFalse);
    });

    test('registrar un pago manual pasa la fecha al mes siguiente', () async {
      final item = await service.saveManual(
          name: 'Administración', amountMinor: 30000000, categoryId: 'hogar', dayOfMonth: 25, remind: true);
      await service.markManualPaid(item, DateTime(2026, 11, 25));
      final p = (await service.list(now: now)).firstWhere((p) => p.isManual);
      expect(p.nextDueAt, DateTime(2026, 12, 25));
    });

    test('el respaldo lleva los pagos manuales y las preferencias', () async {
      final item = await service.saveManual(
          name: 'Arriendo', amountMinor: 120000000, categoryId: 'hogar', dayOfMonth: 5, remind: false);
      final detected = (await service.list(now: now)).firstWhere((p) => !p.isManual);
      await service.dismiss(detected);

      final backup = BackupService(
        transactions: transactions,
        merchantRules: InMemoryMerchantRuleRepository(),
        budgets: InMemoryBudgetRepository(),
        rawNotifications: InMemoryRawNotificationRepository(),
        recurring: recurring,
      );
      const settings = AppSettings(onboardingDone: true, enabledPackages: {});
      final payload = await backup.collect(settings: settings, appVersion: 'Finaid 0.8.0', now: now);
      final json = BackupPayload.fromJson(
          jsonDecode(jsonEncode(payload.toJson())) as Map<String, Object?>);
      expect(json.manualRecurring.single.name, 'Arriendo');
      expect(json.manualRecurring.single.remind, isFalse);
      expect(json.recurringOverrides.single.dismissed, isTrue);

      final other = InMemoryRecurringRepository();
      await BackupService(
        transactions: InMemoryTransactionRepository(),
        merchantRules: InMemoryMerchantRuleRepository(),
        budgets: InMemoryBudgetRepository(),
        rawNotifications: InMemoryRawNotificationRepository(),
        recurring: other,
      ).restore(json, current: settings);
      expect((await other.manual()).single.id, item.id);
      expect((await other.overrides())[detected.id]?.dismissed, isTrue);
    });

    test('respaldos anteriores (sin pagos recurrentes) siguen abriendo', () {
      final json = BackupPayload(
        createdAt: now,
        appVersion: 'Finaid 0.5.1',
        transactions: const [],
        merchantRules: const [],
        budgets: const {},
        notifications: const [],
        settings: const BackupSettings(),
      ).toJson()
        ..remove('recurring_manual')
        ..remove('recurring_overrides');
      final back = BackupPayload.fromJson(json);
      expect(back.manualRecurring, isEmpty);
      expect(back.recurringOverrides, isEmpty);
    });
  });

  group('base de datos', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    test('migra de v1 a v2 y guarda pagos manuales', () async {
      final dir = await Directory.systemTemp.createTemp('finaid_db');
      final path = '${dir.path}/finaid.db';
      final v1 = await openDatabase(path, version: 1, onCreate: (db, _) async {
        await db.execute('CREATE TABLE budgets (category_id TEXT PRIMARY KEY, monthly_limit_minor INTEGER NOT NULL)');
      });
      await v1.close();

      final db = await AppDatabase.open(path: path);
      final repo = SqfliteRecurringRepository(db);
      await repo.upsertManual(ManualRecurring(
        id: 'm1',
        name: 'Arriendo',
        amountMinor: 120000000,
        categoryId: 'hogar',
        dayOfMonth: 5,
        createdAt: DateTime(2026, 1, 1),
        lastPaidMonth: DateTime(2026, 11),
      ));
      await repo.setOverride(const RecurringOverride(recurringId: 'auto:NETFLIX', remind: false));
      final m = (await repo.manual()).single;
      expect(m.lastPaidMonth, DateTime(2026, 11));
      expect((await repo.overrides())['auto:NETFLIX']?.remind, isFalse);
      expect(await db.getVersion(), AppDatabase.version);
      await db.close();
      await dir.delete(recursive: true);
    });
  });
}
