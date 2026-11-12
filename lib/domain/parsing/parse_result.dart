import '../entities/transaction.dart';

/// Transacción extraída de una notificación, todavía sin categoría ni id.
class ParsedTransaction {
  const ParsedTransaction({
    required this.amountMinor,
    required this.currency,
    required this.kind,
    required this.merchantRaw,
    required this.bankId,
    required this.occurredAt,
    required this.confidence,
    this.accountHint,
  });

  final int amountMinor;
  final String currency;
  final TransactionKind kind;
  final String merchantRaw;
  final String bankId;
  final DateTime occurredAt;
  final double confidence;
  final String? accountHint;
}

class ParseOutcome {
  const ParseOutcome.transaction(ParsedTransaction this.transaction)
      : ignoreReason = null;

  const ParseOutcome.ignored(String this.ignoreReason) : transaction = null;

  final ParsedTransaction? transaction;
  final String? ignoreReason;

  bool get isTransaction => transaction != null;
}
