import '../../core/utils/date_utils.dart';
import '../../core/utils/money_format.dart';
import '../entities/category.dart';
import 'recurring.dart';

/// Un aviso programado para una fecha y hora.
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
  });

  /// Estable entre ejecuciones (mismo pago y fecha → mismo id).
  final int id;
  final DateTime at;
  final String title;
  final String body;
}

/// Calcula los avisos de pagos recurrentes de las próximas semanas. El lado
/// nativo los programa con AlarmManager, así llegan aunque la app esté cerrada.
///
/// * Cada pago con aviso activo: [daysBefore] días antes, a las [hour].
/// * Los pagos manuales (que hay que hacer uno mismo) también el mismo día.
class ReminderPlanner {
  ReminderPlanner._();

  static const int defaultHour = 9;
  static const int horizonDays = 45;

  static List<PlannedReminder> plan(
    Iterable<RecurringPayment> payments, {
    required DateTime now,
    required int daysBefore,
    int hour = defaultHour,
  }) {
    final horizon = now.add(const Duration(days: horizonDays));
    final out = <PlannedReminder>[];
    for (final p in payments) {
      if (!p.remind) continue;
      // La próxima fecha y la del mes siguiente, para cubrir el horizonte.
      final first = Dates.dayStart(p.nextDueAt);
      final second = ManualRecurring.dueIn(
          Dates.addMonths(Dates.monthStart(first), 1), first.day);
      for (final due in [first, second]) {
        if (due.isAfter(horizon)) continue;
        if (daysBefore > 0) {
          final at = DateTime(due.year, due.month, due.day - daysBefore, hour);
          if (at.isAfter(now)) {
            out.add(_reminder(p, due, at, daysBefore));
          }
        }
        if (p.isManual) {
          final at = DateTime(due.year, due.month, due.day, hour);
          if (at.isAfter(now)) out.add(_reminder(p, due, at, 0));
        }
      }
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }

  static PlannedReminder _reminder(
      RecurringPayment p, DateTime due, DateTime at, int daysBefore) {
    final verb = p.isManual ? 'vence' : 'se cobra';
    final when = switch (daysBefore) {
      0 => 'Hoy',
      1 => 'Mañana',
      _ => 'En $daysBefore días',
    };
    final category = Categories.byId(p.categoryId);
    final amount = MoneyFormat.format(p.amountMinor, currency: p.currency);
    final approx = p.isManual ? '' : '~';
    final tail = p.isManual && daysBefore == 0
        ? ' · Toca para registrar el pago'
        : ' · ${Dates.dayLabel(due, now: at).toLowerCase()}';
    return PlannedReminder(
      id: stableId('${p.id}|${due.toIso8601String()}|$daysBefore'),
      at: at,
      title: '$when $verb ${p.name}',
      body: '$approx$amount · ${category.emoji} ${category.name}$tail',
    );
  }

  /// FNV-1a de 31 bits: mismo texto → mismo id en cada ejecución.
  static int stableId(String key) {
    var hash = 0x811c9dc5;
    for (final unit in key.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }
}
