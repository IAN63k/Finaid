enum TransactionKind {
  purchase,
  billPayment,
  transferOut,
  withdrawal,
  transferIn,
  deposit,
  refund,
  unknown,
}

extension TransactionKindX on TransactionKind {
  bool get isExpense => switch (this) {
        TransactionKind.purchase ||
        TransactionKind.billPayment ||
        TransactionKind.transferOut ||
        TransactionKind.withdrawal =>
          true,
        _ => false,
      };

  /// Dinero que entra y cuenta como ingreso. Las devoluciones no: restan del
  /// gasto de su categoría (ver [Transaction.expenseImpactMinor]).
  bool get isIncome => switch (this) {
        TransactionKind.transferIn || TransactionKind.deposit => true,
        _ => false,
      };

  bool get isRefund => this == TransactionKind.refund;

  /// Entra dinero (ingreso o devolución).
  bool get isInflow => isIncome || isRefund;

  String get label => switch (this) {
        TransactionKind.purchase => 'Compra',
        TransactionKind.billPayment => 'Pago',
        TransactionKind.transferOut => 'Transferencia enviada',
        TransactionKind.withdrawal => 'Retiro',
        TransactionKind.transferIn => 'Transferencia recibida',
        TransactionKind.deposit => 'Ingreso',
        TransactionKind.refund => 'Devolución',
        TransactionKind.unknown => 'Sin clasificar',
      };

  static TransactionKind fromName(String name) => TransactionKind.values
      .firstWhere((k) => k.name == name, orElse: () => TransactionKind.unknown);
}

/// Cómo se decidió la categoría. Permite saber qué fue manual y qué se puede
/// re-evaluar cuando mejoren las reglas.
enum CategorySource { manual, merchantRule, keywordRule, kind, fallback }

extension CategorySourceX on CategorySource {
  static CategorySource fromName(String name) => CategorySource.values
      .firstWhere((s) => s.name == name, orElse: () => CategorySource.fallback);
}

class Transaction {
  const Transaction({
    required this.id,
    required this.amountMinor,
    required this.currency,
    required this.kind,
    required this.merchantRaw,
    required this.merchantKey,
    required this.bankId,
    required this.occurredAt,
    required this.categoryId,
    required this.categorySource,
    required this.confidence,
    this.rawNotificationId,
    this.accountHint,
    this.ignored = false,
    this.note,
  });

  final String id;
  final String? rawNotificationId;

  /// Monto en unidades menores (centavos). Siempre positivo; el signo lo da [kind].
  final int amountMinor;
  final String currency;
  final TransactionKind kind;
  final String merchantRaw;
  final String merchantKey;
  final String bankId;
  final String? accountHint;
  final DateTime occurredAt;
  final String categoryId;
  final CategorySource categorySource;

  /// Excluida de totales e insights (p. ej. traspaso entre cuentas propias).
  final bool ignored;
  final double confidence;
  final String? note;

  bool get countsAsExpense => !ignored && kind.isExpense;
  bool get countsAsIncome => !ignored && kind.isIncome;

  /// Devolución o reverso de una compra: resta del gasto, no suma ingreso.
  bool get countsAsRefund => !ignored && kind.isRefund;

  /// Efecto sobre el gasto: positivo para gastos, negativo para devoluciones.
  int get expenseImpactMinor => countsAsExpense
      ? amountMinor
      : countsAsRefund
          ? -amountMinor
          : 0;
  bool get needsReview =>
      !ignored && (kind == TransactionKind.unknown || confidence < 0.6);

  Transaction copyWith({
    int? amountMinor,
    String? currency,
    TransactionKind? kind,
    String? merchantRaw,
    String? merchantKey,
    String? bankId,
    String? accountHint,
    DateTime? occurredAt,
    String? categoryId,
    CategorySource? categorySource,
    bool? ignored,
    double? confidence,
    String? note,
  }) =>
      Transaction(
        id: id,
        rawNotificationId: rawNotificationId,
        amountMinor: amountMinor ?? this.amountMinor,
        currency: currency ?? this.currency,
        kind: kind ?? this.kind,
        merchantRaw: merchantRaw ?? this.merchantRaw,
        merchantKey: merchantKey ?? this.merchantKey,
        bankId: bankId ?? this.bankId,
        accountHint: accountHint ?? this.accountHint,
        occurredAt: occurredAt ?? this.occurredAt,
        categoryId: categoryId ?? this.categoryId,
        categorySource: categorySource ?? this.categorySource,
        ignored: ignored ?? this.ignored,
        confidence: confidence ?? this.confidence,
        note: note ?? this.note,
      );
}
