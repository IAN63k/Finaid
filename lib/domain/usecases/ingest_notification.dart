import 'package:uuid/uuid.dart';

import '../../core/utils/text_tools.dart';
import '../categorization/categorizer.dart';
import '../entities/raw_notification.dart';
import '../entities/transaction.dart';
import '../parsing/parse_result.dart';
import '../parsing/parser_registry.dart';
import '../ports/repositories.dart';

enum IngestStatus { ingested, ignored, duplicate }

class IngestResult {
  const IngestResult._(this.status, {this.transaction, this.reason});

  const IngestResult.ingested(Transaction transaction)
      : this._(IngestStatus.ingested, transaction: transaction);

  const IngestResult.ignored(String reason)
      : this._(IngestStatus.ignored, reason: reason);

  const IngestResult.duplicate(String reason)
      : this._(IngestStatus.duplicate, reason: reason);

  final IngestStatus status;
  final Transaction? transaction;
  final String? reason;

  bool get isNewTransaction => status == IngestStatus.ingested;
}

/// Pipeline completo: guardar la notificación cruda → parsear → deduplicar →
/// categorizar → guardar la transacción.
class IngestNotificationUseCase {
  IngestNotificationUseCase({
    required this.rawNotifications,
    required this.transactions,
    required this.merchantRules,
    required this.registry,
    required this.categorizer,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final RawNotificationRepository rawNotifications;
  final TransactionRepository transactions;
  final MerchantRuleRepository merchantRules;
  final ParserRegistry registry;
  final Categorizer categorizer;
  final Uuid _uuid;

  static const Duration dedupeWindow = Duration(minutes: 3);

  Future<IngestResult> call(RawNotification raw) async {
    final key = raw.dedupeKey;
    if (key != null && await rawNotifications.existsByDedupeKey(key)) {
      return const IngestResult.duplicate('notificacion_repetida');
    }
    await rawNotifications.save(raw);

    final outcome = registry.parse(raw);
    if (!outcome.isTransaction) {
      final reason = outcome.ignoreReason ?? 'desconocido';
      await rawNotifications.markProcessed(raw.id,
          status: 'ignored', reason: reason);
      return IngestResult.ignored(reason);
    }

    final parsed = outcome.transaction!;
    final merchantKey = TextTools.merchantKey(parsed.merchantRaw);

    final similar = await transactions.findSimilar(
      amountMinor: parsed.amountMinor,
      around: parsed.occurredAt,
      window: dedupeWindow,
    );
    if (similar.any((t) => _sameEvent(t, parsed, merchantKey))) {
      await rawNotifications.markProcessed(raw.id,
          status: 'duplicate', reason: 'movimiento_repetido');
      return const IngestResult.duplicate('movimiento_repetido');
    }

    final rule = merchantKey.isEmpty
        ? null
        : await merchantRules.byMerchantKey(merchantKey);
    final decision = categorizer.categorize(
      kind: parsed.kind,
      merchantKey: merchantKey,
      fullText: raw.fullText,
      merchantRule: rule,
    );

    final transaction = Transaction(
      id: _uuid.v4(),
      rawNotificationId: raw.id,
      amountMinor: parsed.amountMinor,
      currency: parsed.currency,
      kind: parsed.kind,
      merchantRaw: parsed.merchantRaw,
      merchantKey: merchantKey,
      bankId: parsed.bankId,
      accountHint: parsed.accountHint,
      occurredAt: parsed.occurredAt,
      categoryId: decision.categoryId,
      categorySource: decision.source,
      ignored: rule?.ignore ?? false,
      confidence: parsed.confidence,
    );
    await transactions.save(transaction);
    await rawNotifications.markProcessed(raw.id, status: 'parsed');
    return IngestResult.ingested(transaction);
  }

  /// Misma transacción vista por dos canales (push de la app y SMS, p. ej.).
  bool _sameEvent(Transaction existing, ParsedTransaction parsed, String key) {
    final kindCompatible = existing.kind == parsed.kind ||
        existing.kind == TransactionKind.unknown ||
        parsed.kind == TransactionKind.unknown;
    if (!kindCompatible) return false;
    if (existing.merchantKey.isEmpty || key.isEmpty) return true;
    final a = existing.merchantKey.split(' ').first;
    final b = key.split(' ').first;
    return a == b ||
        existing.merchantKey.contains(key) ||
        key.contains(existing.merchantKey);
  }
}
