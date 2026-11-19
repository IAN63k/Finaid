import 'package:finaid/domain/entities/bank.dart';
import 'package:finaid/domain/entities/raw_notification.dart';
import 'package:finaid/domain/entities/transaction.dart';
import 'package:finaid/domain/parsing/parser_registry.dart';
import 'package:finaid/infrastructure/platform/local_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final registry = ParserRegistry.standard();

  group('textos que llegan desde Atajos (iPhone)', () {
    test('Apple Pay: "Compra por [Monto] en [Comercio]"', () {
      final t = registry
          .parse(raw(
            package: 'ios.wallet',
            text: 'Compra por \$45.900,00 en Éxito Calle 80',
            channel: NotificationChannel.iosShortcut,
          ))
          .transaction!;
      expect(t.kind, TransactionKind.purchase);
      expect(t.amountMinor, 4590000);
      expect(t.merchantRaw, 'Exito Calle 80');
      expect(t.bankId, 'applepay');
    });

    test('Apple Pay con el monto en formato "COP 45.900"', () {
      final t = registry
          .parse(raw(
            package: 'ios.wallet',
            text: 'Compra por COP 45.900 en Rappi',
            channel: NotificationChannel.iosShortcut,
          ))
          .transaction!;
      expect(t.amountMinor, 4590000);
      expect(t.merchantRaw, 'Rappi');
    });

    test('SMS reenviado por la automatización: el banco sale del texto', () {
      final t = registry
          .parse(raw(
            package: 'ios.sms',
            text: Samples.bancolombiaCompra,
            channel: NotificationChannel.iosShortcut,
          ))
          .transaction!;
      expect(t.bankId, 'bancolombia');
      expect(t.merchantRaw, 'EXITO CALLE 80');
    });

    test('Apple Pay no aparece como fuente en Android', () {
      expect(KnownBanks.applePay.packages.every((p) => p.startsWith('ios.')), isTrue);
      expect(KnownBanks.byPackage('ios.wallet')?.id, 'applepay');
    });
  });

  test('sin plugin nativo, el puente de iOS no falla', () async {
    const bridge = IosPlatformBridge();
    expect(await bridge.hasPostNotificationPermission(), isFalse);
    expect(await bridge.deviceInfo(), isNull);
    expect(await bridge.openShortcuts(), isFalse);
    await bridge.scheduleReminders(const []);
    await bridge.showCaptureNotification(title: 't', body: 'b');
  });
}
