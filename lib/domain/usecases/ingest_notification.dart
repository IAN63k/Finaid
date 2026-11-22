import 'package:uuid/uuid.dart';

import '../../core/utils/text_tools.dart';
import '../categorization/categorizer.dart';
import '../entities/raw_notification.dart';
import '../entities/transaction.dart';
import '../parsing/parse_result.dart';
import '../parsing/parser_registry.dart';
import '../ports/repositories.dart';

enum IngestStatus { ingested, ignored, duplicate, selfTest, flagged }

class IngestResult {
  const IngestResult._(this.status,
      {this.transaction, this.reason, this.selfTestOutcome});

  const IngestResult.ingested(Transaction transaction)
      : this._(IngestStatus.ingested, transaction: transaction);

  const IngestResult.ignored(String reason)
      : this._(IngestStatus.ignored, reason: reason);

  const IngestResult.duplicate(String reason)
      : this._(IngestStatus.duplicate, reason: reason);

  /// El banco avisó que una compra no fue exitosa y coincide con una compra ya
  /// registrada: esa compra quedó marcada para revisar ([transaction]).
  const IngestResult.flagged(Transaction transaction)
      : this._(IngestStatus.flagged,
            transaction: transaction, reason: 'rechazada');

  /// La autoprueba de captura llegó: se parsea pero no se guarda movimiento.
  const IngestResult.selfTest(ParseOutcome outcome)
      : this._(IngestStatus.selfTest, selfTestOutcome: outcome);

  final IngestStatus status;
  final Transaction? transaction;
  final String? reason;
  final ParseOutcome? selfTestOutcome;

  bool get isNewTransaction => status == IngestStatus.ingested;
  bool get isFlagged => status == IngestStatus.flagged;
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

  /// Hasta cuánto antes de un aviso de compra no exitosa se busca la compra
  /// registrada con el mismo valor.
  static const Duration rejectedLookback = Duration(hours: 24);

  /// Hasta cuánto antes de una devolución se busca la compra original.
  static const Duration refundLookback = Duration(days: 90);

  /// Comienzo de la nota que deja una compra no exitosa en la compra marcada.
  static const String rejectedNotePrefix = 'Posible compra no exitosa';

  Future<IngestResult> call(RawNotification raw) async {
    final key = raw.dedupeKey;
    if (key != null && await rawNotifications.existsByDedupeKey(key)) {
      return const IngestResult.duplicate('notificacion_repetida');
    }
    await rawNotifications.save(raw);
    return _process(raw);
  }

  /// Vuelve a pasar por el parser las notificaciones que se ignoraron. Útil
  /// cuando una actualización entiende un formato nuevo. Devuelve cuántas
  /// transacciones nuevas se crearon.
  Future<int> reprocessIgnored() async {
    final ignored = await rawNotifications.byStatus('ignored');
    var created = 0;
    for (final raw in ignored) {
      final result = await _process(raw);
      if (result.isNewTransaction) created++;
    }
    return created;
  }

  Future<IngestResult> _process(RawNotification raw) async {
    final outcome = registry.parse(raw);
    if (raw.isSelfTest) {
      await rawNotifications.markProcessed(raw.id,
          status: 'selftest',
          reason: outcome.isTransaction ? 'ok' : outcome.ignoreReason);
      return IngestResult.selfTest(outcome);
    }
    if (!outcome.isTransaction) {
      final reason = outcome.ignoreReason ?? 'desconocido';
      await rawNotifications.markProcessed(raw.id,
          status: 'ignored', reason: reason);
      final rejected = outcome.rejected;
      if (rejected != null) {
        final flagged = await _flagRejected(rejected);
        if (flagged != null) return IngestResult.flagged(flagged);
      }
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
    var decision = categorizer.categorize(
      kind: parsed.kind,
      merchantKey: merchantKey,
      fullText: raw.fullText,
      merchantRule: rule,
    );
    if (parsed.kind == TransactionKind.refund && rule?.categoryId == null) {
      // La devolución resta del gasto de la categoría de la compra original.
      final original = await _originalPurchase(parsed, merchantKey);
      if (original != null) {
        decision =
            (categoryId: original.categoryId, source: CategorySource.kind);
      }
    }

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

  /// Busca la compra registrada que corresponde a un aviso de compra no
  /// exitosa (mismo valor, horas antes, mismo comercio o misma tarjeta) y la
  /// marca para revisar. No la borra: a veces el primer intento sí se cobró y
  /// el que falló fue un reintento.
  Future<Transaction?> _flagRejected(ParsedTransaction rejected) async {
    final key = TextTools.merchantKey(rejected.merchantRaw);
    final hint = rejected.accountHint;
    final latest = rejected.occurredAt.add(const Duration(minutes: 5));
    final candidates = (await transactions.findSimilar(
      amountMinor: rejected.amountMinor,
      around: rejected.occurredAt,
      window: rejectedLookback,
    ))
        .where((t) =>
            t.countsAsExpense &&
            !t.occurredAt.isAfter(latest) &&
            !(t.note?.startsWith(rejectedNotePrefix) ?? false) &&
            (_merchantsMatch(t.merchantKey, key) ||
                (hint != null && t.accountHint == hint)))
        .toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    if (candidates.isEmpty) return null;
    final match = candidates.first;
    const note = '$rejectedNotePrefix: el banco avisó que una compra por el '
        'mismo valor no se cobró. Si no te cobraron, ignórala.';
    final previous = match.note;
    final flagged = match.copyWith(
      confidence: match.confidence < 0.4 ? match.confidence : 0.4,
      note: previous == null || previous.isEmpty ? note : '$note\n$previous',
    );
    await transactions.save(flagged);
    return flagged;
  }

  /// Compra que se está devolviendo: el mismo comercio (de preferencia con el
  /// mismo valor), en los meses anteriores.
  Future<Transaction?> _originalPurchase(
      ParsedTransaction refund, String merchantKey) async {
    final sameAmount = (await transactions.findSimilar(
      amountMinor: refund.amountMinor,
      around: refund.occurredAt,
      window: refundLookback,
    ))
        .where((t) =>
            t.countsAsExpense && !t.occurredAt.isAfter(refund.occurredAt))
        .toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    if (merchantKey.isEmpty) {
      // Sin comercio solo se acepta si hay una única compra con ese valor.
      return sameAmount.length == 1 ? sameAmount.first : null;
    }
    for (final t in sameAmount) {
      if (_merchantsMatch(t.merchantKey, merchantKey)) return t;
    }
    final byMerchant = (await transactions.byMerchantKey(merchantKey))
        .where((t) =>
            t.countsAsExpense &&
            !t.occurredAt.isAfter(refund.occurredAt) &&
            refund.occurredAt.difference(t.occurredAt) <= refundLookback)
        .toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return byMerchant.isEmpty ? null : byMerchant.first;
  }

  static bool _merchantsMatch(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;
    return a.split(' ').first == b.split(' ').first ||
        a.contains(b) ||
        b.contains(a);
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
