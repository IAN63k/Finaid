/// Helpers de fechas (mes calendario, fin de día, etc.).
class Dates {
  Dates._();

  static DateTime monthStart(DateTime d) => DateTime(d.year, d.month);

  /// Primer instante del mes siguiente (límite exclusivo).
  static DateTime nextMonthStart(DateTime d) => DateTime(d.year, d.month + 1);

  static DateTime addMonths(DateTime monthStart, int delta) =>
      DateTime(monthStart.year, monthStart.month + delta);

  static int daysInMonth(DateTime d) => DateTime(d.year, d.month + 1, 0).day;

  static bool sameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool isWeekend(DateTime d) =>
      d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;

  static const List<String> monthNamesEs = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  static const List<String> weekdayNamesEs = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];

  static String monthLabel(DateTime d) {
    final name = monthNamesEs[d.month - 1];
    return '${name[0].toUpperCase()}${name.substring(1)} ${d.year}';
  }

  /// `"Hoy"`, `"Ayer"` o `"martes 10 de noviembre"`.
  static String dayLabel(DateTime d, {DateTime? now}) {
    final today = dayStart(now ?? DateTime.now());
    final day = dayStart(d);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Ayer';
    final weekday = weekdayNamesEs[d.weekday - 1];
    final month = monthNamesEs[d.month - 1];
    final year = d.year == today.year ? '' : ' de ${d.year}';
    return '$weekday ${d.day} de $month$year';
  }

  static String timeLabel(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static String shortDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${timeLabel(d)}';
}
