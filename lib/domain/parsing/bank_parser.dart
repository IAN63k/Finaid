import '../../core/utils/text_tools.dart';
import '../entities/bank.dart';
import '../entities/raw_notification.dart';
import '../entities/transaction.dart';
import 'money_parser.dart';
import 'parse_result.dart';
import 'text_analysis.dart';

/// Contrato de un parser. Un parser sabe reconocer notificaciones de una
/// entidad (por package o por firma en el texto) y convertirlas en
/// [ParsedTransaction].
abstract class BankParser {
  String get bankId;
  bool canHandle(RawNotification notification);
  ParseOutcome parse(RawNotification notification);
}

/// Parser genérico para mensajes bancarios en español. Los parsers de cada
/// banco heredan de aquí y solo ajustan lo particular (prefijos, formatos).
class SpanishBankParser implements BankParser {
  const SpanishBankParser({required this.bank});

  final BankProfile bank;

  @override
  String get bankId => bank.id;

  @override
  bool canHandle(RawNotification notification) {
    if (bank.packages.contains(notification.sourcePackage)) return true;
    if (bank.signatures.isEmpty) return false;
    final t = TextTools.normalize(notification.fullText);
    return bank.signatures.any(t.contains);
  }

  /// Punto de extensión: limpiar prefijos o reordenar texto antes de analizar.
  String preprocess(String text) => text;

  @override
  ParseOutcome parse(RawNotification notification) {
    final original = preprocess(notification.fullText)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final norm = TextTools.normalize(original);

    final detected = KindDetector.detect(norm);
    final hasVerb = detected.kind != TransactionKind.unknown;

    final noise = NoiseFilter.reason(norm, hasVerb: hasVerb);
    if (noise == 'rechazada') {
      return ParseOutcome.ignored(noise,
          rejected: _rejectedDetails(original, notification, detected.kind));
    }
    if (noise != null) return ParseOutcome.ignored(noise);

    final plain = TextTools.removeDiacritics(original);
    var bareAmount = false;
    var money = MoneyParser.parseFirst(original);
    if (money == null && hasVerb) {
      money = MoneyParser.parseBare(plain);
      bareAmount = money != null;
    }
    if (money == null) return const ParseOutcome.ignored('sin_monto');

    if (!hasVerb && !NoiseFilter.looksTransactional(norm)) {
      return const ParseOutcome.ignored('sin_verbo');
    }

    final merchant =
        CounterpartyExtractor.extract(plain, detected.kind, from: money.end) ??
            '';
    final when =
        DateTimeExtractor.extract(original, fallback: notification.postedAt);
    final hint = AccountHintExtractor.extract(original);

    var resolvedBank = bank;
    if (resolvedBank.id == KnownBanks.unknown.id) {
      resolvedBank = KnownBanks.bySignature(norm) ?? KnownBanks.unknown;
    }

    var confidence = 0.4;
    if (resolvedBank.id != KnownBanks.unknown.id) confidence += 0.2;
    if (merchant.isNotEmpty) confidence += 0.2;
    if (detected.strong) confidence += 0.2;
    if (bareAmount) confidence -= 0.1;

    return ParseOutcome.transaction(ParsedTransaction(
      amountMinor: money.amountMinor,
      currency: money.currency,
      kind: detected.kind,
      merchantRaw: merchant,
      bankId: resolvedBank.id,
      occurredAt: when,
      confidence: confidence.clamp(0.0, 1.0).toDouble(),
      accountHint: hint,
    ));
  }

  /// Lo que se puede leer de una compra rechazada o no exitosa ("tu compra
  /// en X no fue exitosa... Valor: $44.300"), para cruzarla con una compra
  /// ya registrada. `null` si no trae monto.
  ParsedTransaction? _rejectedDetails(
      String original, RawNotification notification, TransactionKind kind) {
    final plain = TextTools.removeDiacritics(original);
    final money = MoneyParser.parseFirst(original);
    if (money == null) return null;
    final rejectedKind = kind.isExpense ? kind : TransactionKind.purchase;
    return ParsedTransaction(
      amountMinor: money.amountMinor,
      currency: money.currency,
      kind: rejectedKind,
      merchantRaw:
          CounterpartyExtractor.extract(plain, rejectedKind, from: money.end) ??
              '',
      bankId: bank.id == KnownBanks.unknown.id
          ? (KnownBanks.bySignature(TextTools.normalize(original)) ??
                  KnownBanks.unknown)
              .id
          : bank.id,
      occurredAt:
          DateTimeExtractor.extract(original, fallback: notification.postedAt),
      confidence: 0,
      accountHint: AccountHintExtractor.extract(original),
    );
  }
}
