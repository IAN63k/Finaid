import 'package:flutter/services.dart';

/// Formatea montos en pesos mientras se escriben: `1500000` → `1.500.000`.
///
/// * Solo acepta dígitos; quita ceros a la izquierda.
/// * Mantiene el cursor junto al mismo dígito aunque se agreguen o quiten puntos.
/// * Borrar un punto borra el dígito anterior (lo que el usuario espera).
class MoneyInputFormatter extends TextInputFormatter {
  const MoneyInputFormatter({this.separator = '.', this.maxDigits = 12});

  final String separator;

  /// Límite de dígitos (12 = cientos de miles de millones).
  final int maxDigits;

  static final RegExp _nonDigit = RegExp(r'\D');

  /// `"1500000"` → `"1.500.000"`.
  static String format(String digits, {String separator = '.'}) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(separator);
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  /// Texto del campo → pesos enteros (`"1.500.000"` → 1500000), o `null` si está vacío.
  static int? parse(String text) {
    final digits = text.replaceAll(_nonDigit, '');
    return digits.isEmpty ? null : int.tryParse(digits);
  }

  /// Pesos enteros → texto inicial del campo.
  static String fromPesos(int? pesos, {String separator = '.'}) =>
      pesos == null || pesos <= 0 ? '' : format('$pesos', separator: separator);

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final newText = newValue.text;
    final cursor = _cursorOf(newValue);

    var digitsBeforeCursor =
        newText.substring(0, cursor).replaceAll(_nonDigit, '').length;
    var digits = newText.replaceAll(_nonDigit, '');

    // Se borró solo un separador: borrar también el dígito anterior.
    final oldDigits = oldValue.text.replaceAll(_nonDigit, '');
    final deletedOneChar = newText.length == oldValue.text.length - 1;
    if (deletedOneChar && digits == oldDigits && digitsBeforeCursor > 0) {
      digits = digits.substring(0, digitsBeforeCursor - 1) +
          digits.substring(digitsBeforeCursor);
      digitsBeforeCursor -= 1;
    }

    // Sin ceros a la izquierda ("007" → "7").
    final stripped = digits.replaceFirst(RegExp(r'^0+'), '');
    digitsBeforeCursor =
        (digitsBeforeCursor - (digits.length - stripped.length)).clamp(0, stripped.length);
    digits = stripped;

    if (digits.length > maxDigits) return oldValue;

    final formatted = format(digits, separator: separator);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
          offset: _offsetAfterDigits(formatted, digitsBeforeCursor)),
    );
  }

  static int _cursorOf(TextEditingValue value) {
    final end = value.selection.end;
    if (end < 0 || end > value.text.length) return value.text.length;
    return end;
  }

  /// Posición en [formatted] justo después del dígito número [count].
  static int _offsetAfterDigits(String formatted, int count) {
    if (count <= 0) return 0;
    var seen = 0;
    for (var i = 0; i < formatted.length; i++) {
      if (_nonDigit.hasMatch(formatted[i])) continue;
      seen++;
      if (seen == count) return i + 1;
    }
    return formatted.length;
  }
}
