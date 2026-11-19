import 'package:finaid/domain/entities/raw_notification.dart';
import 'package:finaid/domain/entities/transaction.dart';

int _seq = 0;

RawNotification raw({
  required String package,
  required String text,
  String? title,
  DateTime? postedAt,
  String? dedupeKey,
  NotificationChannel channel = NotificationChannel.androidListener,
}) {
  _seq++;
  return RawNotification(
    id: 'raw_$_seq',
    sourcePackage: package,
    title: title,
    text: text,
    postedAt: postedAt ?? DateTime(2026, 11, 12, 14, 35),
    channel: channel,
    dedupeKey: dedupeKey ?? 'key_$_seq',
  );
}

Transaction tx({
  required int cop,
  required DateTime at,
  TransactionKind kind = TransactionKind.purchase,
  String merchant = '',
  String category = 'otros',
  String bank = 'bancolombia',
  bool ignored = false,
}) {
  _seq++;
  return Transaction(
    id: 'tx_$_seq',
    amountMinor: cop * 100,
    currency: 'COP',
    kind: kind,
    merchantRaw: merchant,
    merchantKey: merchant.toUpperCase(),
    bankId: bank,
    occurredAt: at,
    categoryId: category,
    categorySource: CategorySource.keywordRule,
    confidence: 1,
    ignored: ignored,
  );
}

/// Mensajes reales (anonimizados) de bancos colombianos.
class Samples {
  static const bancolombiaPackage = 'com.todo1.mobile';
  static const nequiPackage = 'com.nequi.MobileApp';
  static const daviplataPackage = 'com.davivienda.daviplataapp';
  static const daviviendaPackage = 'com.davivienda.daviviendaapp';
  static const nuPackage = 'com.nu.production';
  static const smsPackage = 'com.google.android.apps.messaging';

  static const bancolombiaCompra =
      'Bancolombia le informa Compra por \$45.900,00 en EXITO CALLE 80 a las 14:33. 12/11/2026 T.Cred *1234. Inquietudes al 6045109095.';
  static const bancolombiaRetiro =
      'Bancolombia le informa Retiro por \$200.000 en CAJERO SERVIBANCA CC ANDINO a las 18:02. 11/11/2026 T.Deb *5555.';
  static const bancolombiaRechazada =
      'Bancolombia: Compra rechazada por \$50.000 en TIENDA X. Verifica tu cupo.';
  static const bancolombiaOtp =
      'Bancolombia: Tu clave dinámica es 482913. No la compartas con nadie.';
  static const nequiCompra =
      'Compraste \$25.000 en RAPPI con tu tarjeta Nequi *4321. Tu saldo ahora es \$150.000.';
  static const nequiEnvio =
      '¡Listo! Enviaste \$30.000 a Juan Perez. Tu saldo es \$120.000.';
  static const nequiPagoQr =
      'Pagaste \$12.000 a TIENDA DONA ROSA con Nequi. Tu saldo es \$90.000.';
  static const nequiSaldo = 'Tu saldo disponible es \$150.000.';
  static const daviplataIngreso =
      'Te llegaron \$200.000 de MARIA LOPEZ. Saldo: \$350.000';
  static const nuSuscripcion =
      'Compra aprobada: \$35.900 en NETFLIX.COM con tu tarjeta de crédito Nu terminada en 5678.';
  static const nuUsd = 'Compra aprobada: US\$12.99 en OPENAI con tu tarjeta Nu.';
  static const nuPromo = 'Conoce tu nuevo cupo preaprobado de \$2.000.000.';
  static const daviviendaFactura =
      'Davivienda: Pago de factura CLARO por \$89.900 realizado exitosamente desde tu cuenta *9876 el 10/11/2026 a las 09:12.';

  static const bbvaPackage = 'co.com.bbva.mb';

  /// Formato real capturado en un Galaxy S26 Ultra (2026-11-17).
  static const bbvaCompraTitle = 'Compra Exitosa';
  static const bbvaCompra =
      'Hola, realizaste una compra por \$26,190.00 en Mp*agc tecnologia con tu tarjeta BBVA *2484. El 2026-11-17 a las 00:39.';
  static const bbvaLlaveTitle = 'Tu envío con llave fue exitoso';
  static const bbvaLlave =
      '2026/11/14 17:02 ROBIN IBARRA HURTADO recibió el valor de \$ 17.000,00 que enviaste a su llave *****4032 registrada en Nequi. Si no reconoces la operación, comunícate al 01 8000 912 227.';
  static const bbvaLoginTitle = 'Ingreso a App BBVA';
  static const bbvaLogin =
      'BBVA te informa que ingresaste a la App el 2026-11-14 a las 17:01 desde el dispositivo SM-S938B.';
  static const nequiEnvioExitoso =
      'Tu envío por \$20.000 a MARIA GOMEZ fue exitoso.';

  /// Formato real capturado en un Galaxy S26 Ultra (2026-11-17).
  static const nequiTeEnvioTitle = 'Envío';
  static const nequiTeEnvio = 'KAROL CASTANEDA te envió 50, ¡lo mejor!';
  static const nequiPagoSinSimbolo = 'Pagaste 12000 en TIENDA DONA ROSA.';
}
