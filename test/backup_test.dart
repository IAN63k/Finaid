import 'dart:convert';
import 'dart:typed_data';

import 'package:finaid/application/backup_service.dart';
import 'package:finaid/domain/backup/backup_payload.dart';
import 'package:finaid/domain/entities/merchant_rule.dart';
import 'package:finaid/domain/entities/transaction.dart';
import 'package:finaid/infrastructure/backup/backup_codec.dart';
import 'package:finaid/infrastructure/memory/in_memory_repositories.dart';
import 'package:finaid/infrastructure/settings/app_settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fixtures.dart';

BackupPayload _payload() => BackupPayload(
      createdAt: DateTime(2026, 11, 19, 12, 30),
      appVersion: 'Finaid 0.5.0',
      transactions: [
        tx(cop: 26190, at: DateTime(2026, 11, 17, 0, 39), merchant: 'AGC TECNOLOGIA', category: 'compras', bank: 'bbva'),
        tx(cop: 50, at: DateTime(2026, 11, 17, 0, 2), kind: TransactionKind.transferIn, merchant: 'KAROL', category: 'ingresos', bank: 'nequi'),
      ],
      merchantRules: [
        MerchantRule(id: 'r1', merchantKey: 'RAPPI', categoryId: 'mercado', createdAt: DateTime(2026, 11, 1)),
      ],
      budgets: const {'restaurantes': 30000000},
      notifications: const [],
      settings: const BackupSettings(
        notifyCaptures: false,
        expectedMonthlyIncomeMinor: 350000000,
        enabledPackages: ['co.com.bbva.mb'],
        disabledPackages: ['com.whatsapp'],
      ),
    );

void main() {
  group('BackupPayload', () {
    test('ida y vuelta por JSON conserva todo', () {
      final original = _payload();
      final back = BackupPayload.fromJson(
          jsonDecode(jsonEncode(original.toJson())) as Map<String, Object?>);
      expect(back.createdAt, original.createdAt);
      expect(back.transactions.length, 2);
      final t = back.transactions.first;
      expect(t.amountMinor, 2619000);
      expect(t.merchantKey, 'AGC TECNOLOGIA');
      expect(t.bankId, 'bbva');
      expect(back.transactions.last.kind, TransactionKind.transferIn);
      expect(back.merchantRules.single.categoryId, 'mercado');
      expect(back.budgets, {'restaurantes': 30000000});
      expect(back.settings.expectedMonthlyIncomeMinor, 350000000);
      expect(back.settings.disabledPackages, ['com.whatsapp']);
    });

    test('rechaza esquemas desconocidos', () {
      final json = _payload().toJson()..['schema'] = 99;
      expect(() => BackupPayload.fromJson(json), throwsFormatException);
    });
  });

  group('BackupCodec', () {
    final codec = BackupCodec(iterations: 1000);

    test('cifrado: se abre con la contraseña correcta', () async {
      final bytes = await codec.encode(_payload(), password: 'clave-segura');
      final text = utf8.decode(bytes);
      expect(text, isNot(contains('AGC TECNOLOGIA')));
      expect(codec.inspect(bytes).encrypted, isTrue);
      expect(codec.inspect(bytes).createdAt, DateTime(2026, 11, 19, 12, 30));

      final back = await codec.decode(bytes, password: 'clave-segura');
      expect(back.transactions.length, 2);
    });

    test('cifrado: contraseña incorrecta o faltante', () async {
      final bytes = await codec.encode(_payload(), password: 'clave-segura');
      await expectLater(
        () => codec.decode(bytes, password: 'otra'),
        throwsA(isA<BackupException>()
            .having((e) => e.error, 'error', BackupError.wrongPassword)),
      );
      await expectLater(
        () => codec.decode(bytes),
        throwsA(isA<BackupException>()
            .having((e) => e.error, 'error', BackupError.passwordRequired)),
      );
    });

    test('cifrado: un archivo alterado no se abre', () async {
      final bytes = await codec.encode(_payload(), password: 'clave-segura');
      final env = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final data = base64Decode(env['data'] as String);
      data[data.length ~/ 2] ^= 0xFF;
      env['data'] = base64Encode(data);
      final tampered = Uint8List.fromList(utf8.encode(jsonEncode(env)));
      await expectLater(
        () => codec.decode(tampered, password: 'clave-segura'),
        throwsA(isA<BackupException>()
            .having((e) => e.error, 'error', BackupError.wrongPassword)),
      );
    });

    test('sin contraseña queda legible', () async {
      final bytes = await codec.encode(_payload());
      expect(codec.inspect(bytes).encrypted, isFalse);
      expect(utf8.decode(bytes), contains('AGC TECNOLOGIA'));
      final back = await codec.decode(bytes);
      expect(back.merchantRules.single.merchantKey, 'RAPPI');
    });

    test('otros archivos no son respaldos', () {
      expect(
        () => codec.inspect(Uint8List.fromList(utf8.encode('Fecha;Monto\n'))),
        throwsA(isA<BackupException>()
            .having((e) => e.error, 'error', BackupError.notABackup)),
      );
      expect(
        () => codec.inspect(
            Uint8List.fromList(utf8.encode(jsonEncode({'format': 'otro'})))),
        throwsA(isA<BackupException>()
            .having((e) => e.error, 'error', BackupError.notABackup)),
      );
    });

    test('esquema de una versión futura', () async {
      final bytes = await codec.encode(_payload());
      final env = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      (env['payload'] as Map<String, dynamic>)['schema'] = 99;
      final future = Uint8List.fromList(utf8.encode(jsonEncode(env)));
      await expectLater(
        () => codec.decode(future),
        throwsA(isA<BackupException>()
            .having((e) => e.error, 'error', BackupError.unsupportedVersion)),
      );
    });
  });

  group('BackupService', () {
    late InMemoryTransactionRepository transactions;
    late InMemoryMerchantRuleRepository rules;
    late InMemoryBudgetRepository budgets;
    late InMemoryRawNotificationRepository raws;
    late BackupService service;

    setUp(() {
      transactions = InMemoryTransactionRepository();
      rules = InMemoryMerchantRuleRepository();
      budgets = InMemoryBudgetRepository();
      raws = InMemoryRawNotificationRepository();
      service = BackupService(
        transactions: transactions,
        merchantRules: rules,
        budgets: budgets,
        rawNotifications: raws,
      );
    });

    const current = AppSettings(
      onboardingDone: true,
      enabledPackages: {'com.nequi.MobileApp', 'com.whatsapp'},
      disabledPackages: {'co.com.bbva.mb'},
      expectedMonthlyIncomeMinor: 100,
    );

    test('restaurar combina y es idempotente', () async {
      await transactions.save(
          tx(cop: 1000, at: DateTime(2026, 11, 1), merchant: 'LOCAL'));
      await budgets.set('restaurantes', 99);

      final payload = _payload();
      await service.restore(payload, current: current);
      final summary = await service.restore(payload, current: current);

      expect((await transactions.all()).length, 3);
      expect((await rules.all()).single.merchantKey, 'RAPPI');
      expect(await budgets.all(), {'restaurantes': 99},
          reason: 'el presupuesto que ya existía gana');
      expect(summary.budgets, 0);

      final s = summary.settings;
      expect(s.disabledPackages, contains('co.com.bbva.mb'),
          reason: 'lo desactivado en este teléfono se respeta');
      expect(s.enabledPackages, isNot(contains('co.com.bbva.mb')));
      expect(s.enabledPackages, contains('com.whatsapp'),
          reason: 'lo activado aquí no se desactiva por el respaldo');
      expect(s.expectedMonthlyIncomeMinor, 100);
    });

    test('collect reúne repositorios y ajustes', () async {
      await transactions.save(
          tx(cop: 1000, at: DateTime(2026, 11, 1), merchant: 'LOCAL'));
      await rules.upsert(MerchantRule(
          id: 'r9', merchantKey: 'EXITO', categoryId: 'mercado', createdAt: DateTime(2026)));
      await budgets.set('mercado', 500);
      await raws.save(raw(package: Samples.nequiPackage, text: Samples.nequiCompra));

      final p = await service.collect(
          settings: current, appVersion: 'Finaid 0.5.0', now: DateTime(2026, 11, 19));
      expect(p.transactions.length, 1);
      expect(p.merchantRules.single.merchantKey, 'EXITO');
      expect(p.budgets, {'mercado': 500});
      expect(p.notifications.length, 1);
      expect(p.settings.enabledPackages, ['com.nequi.MobileApp', 'com.whatsapp']);
      expect(p.appVersion, 'Finaid 0.5.0');
    });

    test('un respaldo cifrado restaura en un teléfono vacío', () async {
      final codec = BackupCodec(iterations: 1000);
      final bytes = await codec.encode(_payload(), password: '123456');
      final decoded = await codec.decode(bytes, password: '123456');
      final summary = await service.restore(decoded,
          current: const AppSettings(onboardingDone: true, enabledPackages: {}));
      expect(summary.transactions, 2);
      expect((await transactions.all()).length, 2);
      expect(await budgets.all(), {'restaurantes': 30000000});
      expect(summary.settings.expectedMonthlyIncomeMinor, 350000000);
    });
  });
}
