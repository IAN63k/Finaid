import '../core/utils/money_format.dart';
import '../core/utils/text_tools.dart';
import '../domain/entities/bank.dart';
import '../domain/entities/category.dart';
import '../domain/entities/transaction.dart';

/// Texto del aviso que Finaid muestra al registrar un movimiento.
class CaptureNotificationText {
  CaptureNotificationText._();

  static ({String title, String body}) of(Transaction t) {
    final amount = MoneyFormat.format(t.amountMinor, currency: t.currency);
    final merchant = t.merchantRaw.isEmpty
        ? ''
        : TextTools.titleCase(TextTools.merchantKey(t.merchantRaw));
    final bank = KnownBanks.byId(t.bankId).name;
    final category = Categories.byId(t.categoryId);

    final title = switch (t.kind) {
      TransactionKind.purchase =>
        'Compra: $amount${merchant.isEmpty ? '' : ' en $merchant'}',
      TransactionKind.billPayment =>
        'Pago: $amount${merchant.isEmpty ? '' : ' a $merchant'}',
      TransactionKind.transferOut =>
        'Enviaste $amount${merchant.isEmpty ? '' : ' a $merchant'}',
      TransactionKind.withdrawal => 'Retiro: $amount',
      TransactionKind.transferIn ||
      TransactionKind.deposit ||
      TransactionKind.refund =>
        'Ingreso: $amount${merchant.isEmpty ? '' : ' de $merchant'}',
      TransactionKind.unknown => 'Movimiento: $amount',
    };
    final review = t.needsReview ? ' · Toca para revisar' : '';
    return (
      title: title,
      body: '${category.emoji} ${category.name} · $bank$review',
    );
  }
}
