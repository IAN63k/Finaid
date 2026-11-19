import '../core/utils/money_format.dart';
import '../core/utils/text_tools.dart';
import '../domain/budgets/budget_check.dart';
import '../domain/entities/bank.dart';
import '../domain/entities/category.dart';
import '../domain/entities/transaction.dart';

/// Texto del aviso que Finaid muestra al registrar un movimiento.
class CaptureNotificationText {
  CaptureNotificationText._();

  static ({String title, String body}) of(Transaction t, {BudgetCheck? budget}) {
    final category = Categories.byId(t.categoryId);
    final bank = KnownBanks.byId(t.bankId).name;
    final review = t.needsReview ? ' · Toca para revisar' : '';
    final budgetLine =
        budget == null ? '' : '\n${BudgetAlertText.line(budget)}';
    return (
      title: title(t),
      body: '${category.emoji} ${category.name} · $bank$review$budgetLine',
    );
  }

  /// "Compra: $45.900 en Rappi", "Enviaste $50 a Karol", …
  static String title(Transaction t) {
    final amount = MoneyFormat.format(t.amountMinor, currency: t.currency);
    final merchant = t.merchantRaw.isEmpty
        ? ''
        : TextTools.titleCase(TextTools.merchantKey(t.merchantRaw));
    return switch (t.kind) {
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
  }
}

/// Textos de presupuesto: la línea que acompaña cada compra y la alerta al
/// cruzar el 80% o el 100%.
class BudgetAlertText {
  BudgetAlertText._();

  static String _money(int minor) => MoneyFormat.format(minor);

  /// Línea corta para el aviso de cada compra.
  static String line(BudgetCheck c) {
    final name = Categories.byId(c.categoryId).name;
    final pct = MoneyFormat.percent(c.ratio);
    return switch (c.level) {
      BudgetLevel.ok =>
        '📊 $pct del presupuesto de $name · quedan ${_money(c.remainingMinor)}',
      BudgetLevel.warning =>
        '⚠️ $pct del presupuesto de $name · quedan ${_money(c.remainingMinor)}',
      BudgetLevel.exceeded =>
        '🚨 Presupuesto de $name superado por ${_money(-c.remainingMinor)}',
    };
  }

  /// Alerta destacada al cruzar un umbral.
  static ({String title, String body}) alert(BudgetCheck c, Transaction t) {
    final name = Categories.byId(c.categoryId).name;
    final title = c.level == BudgetLevel.exceeded
        ? '🚨 Superaste tu presupuesto de $name'
        : '⚠️ Vas en el ${MoneyFormat.percent(c.ratio)} de tu presupuesto de $name';
    final days = c.daysLeft == 1 ? '1 día' : '${c.daysLeft} días';
    final status = c.level == BudgetLevel.exceeded
        ? 'Llevas ${_money(c.spentAfterMinor)} de ${_money(c.limitMinor)} este mes.'
        : 'Te quedan ${_money(c.remainingMinor)} para $days.';
    return (
      title: title,
      body: '${CaptureNotificationText.title(t)}. $status',
    );
  }
}

/// Un aviso que hay que mostrar tras registrar un movimiento.
class CaptureAlert {
  const CaptureAlert({
    required this.title,
    required this.body,
    this.isBudgetAlert = false,
  });

  final String title;
  final String body;

  /// Va por el canal de alertas de presupuesto (más visible).
  final bool isBudgetAlert;
}

/// Decide qué avisar al registrar un movimiento:
///
/// * Si el gasto cruza el 80% o el 100% del presupuesto y las alertas están
///   activas: una sola alerta de presupuesto (reemplaza al aviso normal).
/// * Si no: el aviso normal (si está activo), con la línea del presupuesto
///   cuando la categoría tiene uno.
class CaptureAlerts {
  CaptureAlerts._();

  static List<CaptureAlert> plan({
    required Transaction transaction,
    BudgetCheck? budget,
    required bool notifyCaptures,
    required bool budgetAlerts,
  }) {
    final b = budgetAlerts ? budget : null;
    if (b != null && b.crossedThreshold) {
      final text = BudgetAlertText.alert(b, transaction);
      return [CaptureAlert(title: text.title, body: text.body, isBudgetAlert: true)];
    }
    if (!notifyCaptures) return const [];
    final text = CaptureNotificationText.of(transaction, budget: b);
    return [CaptureAlert(title: text.title, body: text.body)];
  }
}
