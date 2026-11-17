class ParsedMoney {
  const ParsedMoney({
    required this.amountMinor,
    required this.currency,
    required this.start,
    required this.end,
  });

  /// Monto en unidades menores (centavos).
  final int amountMinor;
  final String currency;

  /// Posición del match dentro del texto original (para buscar el comercio
  /// después del monto).
  final int start;
  final int end;
}

/// Encuentra montos en texto en español/colombiano:
/// `$45.900,00`, `$ 45.900`, `COP 45900`, `$45,900` (estilo Nu), `US$12.50`.
///
/// Evita confundirse con fechas (`12/11/2026`), horas (`14:33`), últimos
/// dígitos de tarjeta (`*1234`) y números sueltos sin moneda.
class MoneyParser {
  MoneyParser._();

  static final RegExp _pattern = RegExp(
    r'(?:(COP|USD|US\$|U\$|\$|€)\s?)?'
    r'(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?)'
    r'(?:\s?(COP|USD|pesos|dolares|dólares))?',
    caseSensitive: false,
  );

  static final RegExp _grouped = RegExp(r'[.,]\d{3}');
  static final RegExp _letter = RegExp(r'[A-Za-z]');
  static final RegExp _digit = RegExp(r'\d');

  static ParsedMoney? parseFirst(String text) {
    final all = parseAll(text);
    return all.isEmpty ? null : all.first;
  }

  static List<ParsedMoney> parseAll(String text) {
    final results = <ParsedMoney>[];
    for (final m in _pattern.allMatches(text)) {
      final cur1 = m.group(1);
      final number = m.group(2)!;
      final cur2 = m.group(3);
      final hasCurrency = cur1 != null || cur2 != null;

      if (!hasCurrency && !_grouped.hasMatch(number)) continue;

      final numStart = m.start + (cur1 == null ? 0 : m.group(0)!.indexOf(number));
      if (numStart > 0) {
        final prev = text[numStart - 1];
        if ('*/:-#'.contains(prev) || _digit.hasMatch(prev)) continue;
        if (!hasCurrency && _letter.hasMatch(prev)) continue;
      }
      if (m.end < text.length) {
        final next = text[m.end];
        if ('/:%'.contains(next)) continue;
        if (!hasCurrency && _letter.hasMatch(next)) continue;
      }

      final minor = toMinor(number);
      if (minor <= 0) continue;
      results.add(ParsedMoney(
        amountMinor: minor,
        currency: _currencyOf(cur1 ?? cur2),
        start: m.start,
        end: m.end,
      ));
    }
    return results;
  }

  /// Nequi y otras billeteras a veces no ponen símbolo ni separador de miles:
  /// "KAROL te envió 50", "Pagaste 12000 en TIENDA". Solo se usa cuando ya se
  /// detectó un verbo transaccional y [parseFirst] no encontró nada. El número
  /// debe ir justo después del verbo o de "por/de/valor de".
  static final RegExp _bareAfterVerb = RegExp(
    r'(?:envio|enviaste|compraste|pagaste|recibiste|retiraste|pasaste|'
    r'llegaron|transferiste|mandaste|sacaste|metiste|recargaste|recibio|'
    r'valor de|suma de|total de|por|de)\s+\$?\s?'
    r'(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?)(?![\d/:%])',
    caseSensitive: false,
  );

  static ParsedMoney? parseBare(String text) {
    for (final m in _bareAfterVerb.allMatches(text)) {
      final number = m.group(1)!;
      final minor = toMinor(number);
      if (minor <= 0) continue;
      final whole = minor ~/ 100;
      final looksLikeYear =
          !number.contains(RegExp(r'[.,]')) && whole >= 1990 && whole <= 2100;
      if (looksLikeYear) continue;
      return ParsedMoney(
        amountMinor: minor,
        currency: 'COP',
        start: m.start,
        end: m.end,
      );
    }
    return null;
  }

  static String _currencyOf(String? marker) {
    final m = (marker ?? '').toUpperCase();
    if (m == 'USD' || m == 'US\$' || m == 'U\$' || m.startsWith('DOL')) {
      return 'USD';
    }
    if (m == '€') return 'EUR';
    return 'COP';
  }

  /// Convierte `"45.900,00"`, `"45.900"`, `"45,900"`, `"25.50"` o `"100"` a
  /// unidades menores. Si hay dos separadores el último es el decimal; si hay
  /// uno solo, tres dígitos después significan miles.
  static int toMinor(String raw) {
    final s = raw.trim();
    final hasDot = s.contains('.');
    final hasComma = s.contains(',');
    String intPart;
    var fracPart = '';

    if (hasDot && hasComma) {
      final decSep = s.lastIndexOf('.') > s.lastIndexOf(',') ? '.' : ',';
      final idx = s.lastIndexOf(decSep);
      final tail = s.substring(idx + 1);
      if (tail.length == 3) {
        intPart = s.replaceAll(RegExp(r'[.,]'), '');
      } else {
        intPart = s.substring(0, idx).replaceAll(RegExp(r'[.,]'), '');
        fracPart = tail;
      }
    } else if (hasDot || hasComma) {
      final parts = s.split(hasDot ? '.' : ',');
      final tail = parts.last;
      final allGroupsOfThree =
          parts.length >= 2 && parts.sublist(1).every((p) => p.length == 3);
      if (allGroupsOfThree) {
        intPart = parts.join();
      } else if (parts.length == 2 && tail.length <= 2) {
        intPart = parts.first;
        fracPart = tail;
      } else {
        intPart = parts.join();
      }
    } else {
      intPart = s;
    }

    final whole = int.tryParse(intPart) ?? 0;
    final frac = fracPart.isEmpty
        ? 0
        : int.tryParse(fracPart.padRight(2, '0').substring(0, 2)) ?? 0;
    return whole * 100 + frac;
  }
}
