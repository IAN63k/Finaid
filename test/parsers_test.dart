import 'package:finaid/domain/entities/raw_notification.dart';
import 'package:finaid/domain/entities/transaction.dart';
import 'package:finaid/domain/parsing/parser_registry.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fixtures.dart';

void main() {
  final registry = ParserRegistry.standard();

  group('Bancolombia', () {
    test('compra con tarjeta', () {
      final outcome = registry.parse(raw(
        package: Samples.bancolombiaPackage,
        title: 'Bancolombia',
        text: Samples.bancolombiaCompra,
        postedAt: DateTime(2026, 11, 12, 14, 35),
      ));
      expect(outcome.isTransaction, isTrue);
      final t = outcome.transaction!;
      expect(t.amountMinor, 4590000);
      expect(t.currency, 'COP');
      expect(t.kind, TransactionKind.purchase);
      expect(t.merchantRaw, 'EXITO CALLE 80');
      expect(t.bankId, 'bancolombia');
      expect(t.accountHint, '1234');
      expect(t.occurredAt, DateTime(2026, 11, 12, 14, 33));
      expect(t.confidence, 1.0);
    });

    test('retiro en cajero', () {
      final t = registry
          .parse(raw(
            package: Samples.bancolombiaPackage,
            text: Samples.bancolombiaRetiro,
            postedAt: DateTime(2026, 11, 11, 18, 3),
          ))
          .transaction!;
      expect(t.kind, TransactionKind.withdrawal);
      expect(t.amountMinor, 20000000);
      expect(t.merchantRaw, 'CAJERO SERVIBANCA CC ANDINO');
      expect(t.accountHint, '5555');
    });

    test('compra rechazada se ignora', () {
      final outcome = registry.parse(raw(
        package: Samples.bancolombiaPackage,
        text: Samples.bancolombiaRechazada,
      ));
      expect(outcome.isTransaction, isFalse);
      expect(outcome.ignoreReason, 'rechazada');
    });

    test('clave dinámica por SMS se ignora y se reconoce el banco', () {
      final n = raw(
        package: Samples.smsPackage,
        title: 'Bancolombia',
        text: Samples.bancolombiaOtp,
      );
      expect(registry.resolve(n).bankId, 'bancolombia');
      final outcome = registry.parse(n);
      expect(outcome.isTransaction, isFalse);
      expect(outcome.ignoreReason, 'codigo_seguridad');
    });

    test('el mismo mensaje por SMS se parsea igual que el push', () {
      final push = registry
          .parse(raw(
            package: Samples.bancolombiaPackage,
            text: Samples.bancolombiaCompra,
          ))
          .transaction!;
      final sms = registry
          .parse(raw(
            package: Samples.smsPackage,
            title: 'Bancolombia',
            text: Samples.bancolombiaCompra,
            channel: NotificationChannel.sms,
          ))
          .transaction!;
      expect(sms.amountMinor, push.amountMinor);
      expect(sms.merchantRaw, push.merchantRaw);
      expect(sms.bankId, push.bankId);
      expect(sms.occurredAt, push.occurredAt);
    });
  });

  group('Nequi', () {
    test('compra', () {
      final t = registry
          .parse(raw(
            package: Samples.nequiPackage,
            title: 'Nequi',
            text: Samples.nequiCompra,
          ))
          .transaction!;
      expect(t.kind, TransactionKind.purchase);
      expect(t.amountMinor, 2500000);
      expect(t.merchantRaw, 'RAPPI');
      expect(t.accountHint, '4321');
      expect(t.bankId, 'nequi');
    });

    test('envío a persona', () {
      final t = registry
          .parse(raw(
            package: Samples.nequiPackage,
            title: 'Nequi',
            text: Samples.nequiEnvio,
          ))
          .transaction!;
      expect(t.kind, TransactionKind.transferOut);
      expect(t.amountMinor, 3000000);
      expect(t.merchantRaw, 'Juan Perez');
    });

    test('pago QR a comercio es compra', () {
      final t = registry
          .parse(raw(package: Samples.nequiPackage, text: Samples.nequiPagoQr))
          .transaction!;
      expect(t.kind, TransactionKind.purchase);
      expect(t.amountMinor, 1200000);
      expect(t.merchantRaw, 'TIENDA DONA ROSA');
    });

    test('aviso de saldo sin movimiento se ignora', () {
      final outcome = registry
          .parse(raw(package: Samples.nequiPackage, text: Samples.nequiSaldo));
      expect(outcome.isTransaction, isFalse);
      expect(outcome.ignoreReason, 'sin_verbo');
    });
  });

  group('DaviPlata', () {
    test('ingreso recibido', () {
      final t = registry
          .parse(raw(
            package: Samples.daviplataPackage,
            title: 'DaviPlata',
            text: Samples.daviplataIngreso,
          ))
          .transaction!;
      expect(t.kind, TransactionKind.transferIn);
      expect(t.amountMinor, 20000000);
      expect(t.merchantRaw, 'MARIA LOPEZ');
      expect(t.bankId, 'daviplata');
    });
  });

  group('Nu', () {
    test('compra de suscripción con dominio', () {
      final t = registry
          .parse(raw(
            package: Samples.nuPackage,
            title: 'Nu',
            text: Samples.nuSuscripcion,
          ))
          .transaction!;
      expect(t.kind, TransactionKind.purchase);
      expect(t.amountMinor, 3590000);
      expect(t.merchantRaw, 'NETFLIX.COM');
      expect(t.accountHint, '5678');
      expect(t.bankId, 'nu');
    });

    test('compra en dólares', () {
      final t = registry
          .parse(raw(package: Samples.nuPackage, text: Samples.nuUsd))
          .transaction!;
      expect(t.currency, 'USD');
      expect(t.amountMinor, 1299);
      expect(t.merchantRaw, 'OPENAI');
    });

    test('promoción de cupo se ignora', () {
      final outcome =
          registry.parse(raw(package: Samples.nuPackage, text: Samples.nuPromo));
      expect(outcome.isTransaction, isFalse);
      expect(outcome.ignoreReason, 'promocion');
    });
  });

  group('Davivienda (parser genérico)', () {
    test('pago de factura toma el servicio como contraparte', () {
      final t = registry
          .parse(raw(
            package: Samples.daviviendaPackage,
            title: 'Davivienda',
            text: Samples.daviviendaFactura,
            postedAt: DateTime(2026, 11, 10, 9, 13),
          ))
          .transaction!;
      expect(t.kind, TransactionKind.billPayment);
      expect(t.amountMinor, 8990000);
      expect(t.merchantRaw, 'CLARO');
      expect(t.accountHint, '9876');
      expect(t.occurredAt, DateTime(2026, 11, 10, 9, 12));
      expect(t.bankId, 'davivienda');
    });
  });

  group('BBVA (formato real de compra)', () {
    test('compra con tarjeta, procesador Mercado Pago y fecha ISO', () {
      final t = registry
          .parse(raw(
            package: Samples.bbvaPackage,
            title: Samples.bbvaCompraTitle,
            text: Samples.bbvaCompra,
            postedAt: DateTime(2026, 11, 17, 0, 39, 30),
          ))
          .transaction!;
      expect(t.kind, TransactionKind.purchase);
      expect(t.amountMinor, 2619000);
      expect(t.currency, 'COP');
      expect(t.merchantRaw, 'agc tecnologia');
      expect(t.accountHint, '2484');
      expect(t.occurredAt, DateTime(2026, 11, 17, 0, 39));
      expect(t.bankId, 'bbva');
      expect(t.confidence, 1.0);
    });
  });

  group('BBVA (llaves Bre-B)', () {
    test('envío con llave: destinatario antes del verbo y fecha ISO', () {
      final t = registry
          .parse(raw(
            package: Samples.bbvaPackage,
            title: Samples.bbvaLlaveTitle,
            text: Samples.bbvaLlave,
            postedAt: DateTime(2026, 11, 14, 17, 3),
          ))
          .transaction!;
      expect(t.kind, TransactionKind.transferOut);
      expect(t.amountMinor, 1700000);
      expect(t.merchantRaw, 'ROBIN IBARRA HURTADO');
      expect(t.occurredAt, DateTime(2026, 11, 14, 17, 2));
      expect(t.bankId, 'bbva');
      expect(t.confidence, 1.0);
    });

    test('aviso de inicio de sesión se ignora', () {
      final outcome = registry.parse(raw(
        package: Samples.bbvaPackage,
        title: Samples.bbvaLoginTitle,
        text: Samples.bbvaLogin,
      ));
      expect(outcome.isTransaction, isFalse);
      expect(outcome.ignoreReason, 'seguridad');
    });
  });

  group('Nequi (formato real sin símbolo de pesos)', () {
    test('"X te envió 50" es ingreso de 50 pesos con remitente', () {
      final t = registry
          .parse(raw(
            package: Samples.nequiPackage,
            title: Samples.nequiTeEnvioTitle,
            text: Samples.nequiTeEnvio,
          ))
          .transaction!;
      expect(t.kind, TransactionKind.transferIn);
      expect(t.amountMinor, 5000);
      expect(t.currency, 'COP');
      expect(t.merchantRaw, 'KAROL CASTANEDA');
      expect(t.bankId, 'nequi');
      expect(t.confidence, closeTo(0.9, 0.001));
    });

    test('pago sin símbolo ni separador', () {
      final t = registry
          .parse(raw(
            package: Samples.nequiPackage,
            text: Samples.nequiPagoSinSimbolo,
          ))
          .transaction!;
      expect(t.kind, TransactionKind.purchase);
      expect(t.amountMinor, 1200000);
      expect(t.merchantRaw, 'TIENDA DONA ROSA');
    });

    test('un número suelto sin verbo sigue sin ser un movimiento', () {
      final outcome = registry.parse(raw(
        package: Samples.nequiPackage,
        text: 'Tu código de verificación es 482913.',
      ));
      expect(outcome.isTransaction, isFalse);
    });
  });

  group('Nequi (formato "tu envío ... fue exitoso")', () {
    test('se detecta como transferencia enviada', () {
      final t = registry
          .parse(raw(
            package: Samples.nequiPackage,
            title: 'Nequi',
            text: Samples.nequiEnvioExitoso,
          ))
          .transaction!;
      expect(t.kind, TransactionKind.transferOut);
      expect(t.amountMinor, 2000000);
      expect(t.merchantRaw, 'MARIA GOMEZ');
    });
  });

  group('Banco desconocido', () {
    test('se reconoce por firma en el texto', () {
      final n = raw(
        package: 'com.otro.banco',
        text: 'BBVA: Compra por \$10.000 en D1 SAS aprobada.',
      );
      final t = registry.parse(n).transaction!;
      expect(t.bankId, 'bbva');
      expect(t.merchantRaw, 'D1 SAS');
    });

    test('sin firma queda como desconocido con menor confianza', () {
      final t = registry
          .parse(raw(
            package: 'com.otro.banco',
            text: 'Compra por \$10.000 en D1 SAS aprobada.',
          ))
          .transaction!;
      expect(t.bankId, 'desconocido');
      expect(t.confidence, lessThan(1.0));
    });
  });
}
