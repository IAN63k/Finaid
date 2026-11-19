import '../entities/bank.dart';
import '../entities/category.dart';
import '../entities/transaction.dart';

/// Exporta movimientos a CSV pensado para Excel en español:
///
/// * separador `;` y decimales con coma (configuración regional de Colombia),
/// * BOM UTF-8 para que Excel muestre bien las tildes,
/// * gastos en negativo e ingresos en positivo,
/// * protección contra inyección de fórmulas: los textos vienen de notificaciones
///   de terceros, así que un comercio que empiece por `=`, `+`, `-` o `@` se
///   antepone con `'`.
class TransactionsCsv {
  TransactionsCsv._();

  static const String bom = '﻿';
  static const String separator = ';';

  static const List<String> header = [
    'Fecha',
    'Hora',
    'Tipo',
    'Comercio o concepto',
    'Categoría',
    'Banco',
    'Cuenta o tarjeta',
    'Monto',
    'Moneda',
    'Ignorado',
    'Nota',
  ];

  static String build(Iterable<Transaction> transactions) {
    final rows = transactions.toList()
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    final b = StringBuffer(bom)..write(_line(header));
    for (final t in rows) {
      b.write(_line([
        _date(t.occurredAt),
        _time(t.occurredAt),
        t.kind.label,
        _safeText(t.merchantRaw),
        Categories.byId(t.categoryId).name,
        KnownBanks.byId(t.bankId).name,
        t.accountHint == null ? '' : '*${t.accountHint}',
        _amount(t),
        t.currency,
        t.ignored ? 'Sí' : 'No',
        _safeText(t.note ?? ''),
      ]));
    }
    return b.toString();
  }

  static String _line(List<String> fields) =>
      '${fields.map(_escape).join(separator)}\r\n';

  static String _escape(String field) {
    final needsQuotes = field.contains(separator) ||
        field.contains('"') ||
        field.contains('\n') ||
        field.contains('\r');
    if (!needsQuotes) return field;
    return '"${field.replaceAll('"', '""')}"';
  }

  static String _safeText(String value) {
    final v = value.trim();
    if (v.isEmpty) return v;
    return '=+-@\t\r'.contains(v[0]) ? "'$v" : v;
  }

  static String _amount(Transaction t) {
    final sign = t.kind.isExpense ? '-' : '';
    final whole = t.amountMinor ~/ 100;
    final cents = t.amountMinor % 100;
    return cents == 0
        ? '$sign$whole'
        : '$sign$whole,${cents.toString().padLeft(2, '0')}';
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  static String _date(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

  static String _time(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';
}
