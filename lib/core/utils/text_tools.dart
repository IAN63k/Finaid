/// Utilidades de texto independientes de plataforma.
class TextTools {
  TextTools._();

  static const String _from =
      'áàäâãéèëêíìïîóòöôõúùüûñçÁÀÄÂÃÉÈËÊÍÌÏÎÓÒÖÔÕÚÙÜÛÑÇ';
  static const String _to =
      'aaaaaeeeeiiiiooooouuuuncAAAAAEEEEIIIIOOOOOUUUUNC';

  /// Quita tildes y diéresis (incluida la ñ → n) conservando mayúsculas.
  static String removeDiacritics(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      final index = _from.indexOf(ch);
      buffer.write(index >= 0 ? _to[index] : ch);
    }
    return buffer.toString();
  }

  /// Minúsculas, sin tildes y con espacios colapsados. Para detectar patrones.
  static String normalize(String input) => removeDiacritics(input)
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Clave estable de comercio: mayúsculas, sin tildes ni símbolos.
  /// `"Uber *Trip  Bogotá"` → `"UBER TRIP BOGOTA"`.
  static String merchantKey(String raw) {
    var s = removeDiacritics(raw).toUpperCase();
    s = s.replaceAll(RegExp(r'[^A-Z0-9 ]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  /// `"EXITO CALLE 80"` → `"Exito Calle 80"`. Siglas cortas quedan en mayúscula.
  static String titleCase(String input) => input
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w.length <= 2
          ? w.toUpperCase()
          : w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
}
