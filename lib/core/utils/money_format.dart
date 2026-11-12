/// Formateo de dinero sin depender de datos de locale.
/// Los montos se manejan siempre como enteros en unidades menores (centavos).
class MoneyFormat {
  MoneyFormat._();

  static String format(int minor, {String currency = 'COP'}) {
    final negative = minor < 0;
    final abs = minor.abs();
    final whole = abs ~/ 100;
    final cents = abs % 100;
    final digits = whole.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    var body = buffer.toString();
    if (cents != 0 || currency != 'COP') {
      body = '$body,${cents.toString().padLeft(2, '0')}';
    }
    final symbol = switch (currency) {
      'USD' => 'US\$',
      'EUR' => '€',
      _ => '\$',
    };
    return '${negative ? '-' : ''}$symbol$body';
  }

  /// Versión corta para tarjetas y gráficos: `$1,2M`, `$45K`.
  static String compact(int minor) {
    final value = minor / 100;
    final abs = value.abs();
    final sign = value < 0 ? '-' : '';
    if (abs >= 1000000) {
      final m = (abs / 1000000).toStringAsFixed(1).replaceAll('.', ',');
      return '$sign\$${m}M';
    }
    if (abs >= 10000) {
      return '$sign\$${(abs / 1000).toStringAsFixed(0)}K';
    }
    return format(minor);
  }

  static String percent(double ratio, {int decimals = 0}) =>
      '${(ratio * 100).toStringAsFixed(decimals).replaceAll('.', ',')}%';
}
