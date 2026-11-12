import '../../entities/bank.dart';
import '../bank_parser.dart';

/// Bancolombia: "Bancolombia le informa Compra por $45.900,00 en EXITO ...".
class BancolombiaParser extends SpanishBankParser {
  const BancolombiaParser() : super(bank: KnownBanks.bancolombia);

  static final RegExp _prefix = RegExp(
    r'^(?:bancolombia(?:\s+le\s+informa)?[:.]?\s*)+',
    caseSensitive: false,
  );

  @override
  String preprocess(String text) => text.replaceFirst(_prefix, '');
}

/// Nequi: "Nequi: Compraste $25.000 en RAPPI", "Enviaste $30.000 a Juan".
class NequiParser extends SpanishBankParser {
  const NequiParser() : super(bank: KnownBanks.nequi);

  static final RegExp _prefix = RegExp(
    r'^(?:nequi[:.]?\s*|¡?listo!?[:.]?\s*)+',
    caseSensitive: false,
  );

  @override
  String preprocess(String text) => text.replaceFirst(_prefix, '');
}

/// DaviPlata: "Pasaste $20.000 a ...", "Te llegaron $...", "Sacaste $...".
class DaviPlataParser extends SpanishBankParser {
  const DaviPlataParser() : super(bank: KnownBanks.daviplata);

  static final RegExp _prefix =
      RegExp(r'^(?:daviplata[:.]?\s*)+', caseSensitive: false);

  @override
  String preprocess(String text) => text.replaceFirst(_prefix, '');
}

/// Nu: "Compra aprobada: $35,900 en NETFLIX con tu tarjeta Nu".
class NuParser extends SpanishBankParser {
  const NuParser() : super(bank: KnownBanks.nu);

  static final RegExp _prefix =
      RegExp(r'^(?:nu(?:bank)?[:.]\s*)+', caseSensitive: false);

  @override
  String preprocess(String text) => text.replaceFirst(_prefix, '');
}
