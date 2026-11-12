import '../entities/bank.dart';
import '../entities/raw_notification.dart';
import 'bank_parser.dart';
import 'parse_result.dart';
import 'parsers/colombian_parsers.dart';

/// Elige el parser adecuado para cada notificación. El primero que reconoce
/// la notificación (por package o firma) gana; si ninguno, el genérico.
class ParserRegistry {
  ParserRegistry(this._parsers, this._fallback);

  factory ParserRegistry.standard() {
    final specialized = <BankParser>[
      const BancolombiaParser(),
      const NequiParser(),
      const DaviPlataParser(),
      const NuParser(),
    ];
    final covered = specialized.map((p) => p.bankId).toSet();
    final generic = KnownBanks.all
        .where((b) => !covered.contains(b.id))
        .map((b) => SpanishBankParser(bank: b));
    return ParserRegistry(
      [...specialized, ...generic],
      const SpanishBankParser(bank: KnownBanks.unknown),
    );
  }

  final List<BankParser> _parsers;
  final BankParser _fallback;

  BankParser resolve(RawNotification notification) {
    for (final p in _parsers) {
      if (p.canHandle(notification)) return p;
    }
    return _fallback;
  }

  ParseOutcome parse(RawNotification notification) =>
      resolve(notification).parse(notification);
}
