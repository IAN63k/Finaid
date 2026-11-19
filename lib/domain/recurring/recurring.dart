import 'dart:math' as math;

import '../../core/utils/date_utils.dart';

enum RecurringSource {
  /// Detectado en el historial (cobros mensuales del mismo comercio).
  detected,

  /// Agregado por el usuario (arriendo en efectivo, servicios sin notificación…).
  manual,
}

/// Un pago que se repite cada mes, con su próxima fecha.
class RecurringPayment {
  const RecurringPayment({
    required this.id,
    required this.name,
    required this.amountMinor,
    required this.categoryId,
    required this.nextDueAt,
    required this.source,
    this.merchantKey = '',
    this.currency = 'COP',
    this.lastPaidAt,
    this.occurrences = 0,
    this.remind = true,
  });

  /// `auto:<COMERCIO>` para los detectados, el id del registro para los manuales.
  final String id;
  final String name;

  /// Monto esperado (para los detectados, el del último cobro).
  final int amountMinor;
  final String currency;
  final String categoryId;
  final DateTime nextDueAt;
  final RecurringSource source;
  final String merchantKey;
  final DateTime? lastPaidAt;

  /// Veces que se vio el cobro (solo detectados).
  final int occurrences;

  /// Avisar antes de la fecha.
  final bool remind;

  bool get isManual => source == RecurringSource.manual;

  /// Días hasta la próxima fecha (negativo si ya pasó).
  int daysUntil(DateTime now) =>
      Dates.dayStart(nextDueAt).difference(Dates.dayStart(now)).inDays;

  RecurringPayment copyWith({bool? remind}) => RecurringPayment(
        id: id,
        name: name,
        amountMinor: amountMinor,
        categoryId: categoryId,
        nextDueAt: nextDueAt,
        source: source,
        merchantKey: merchantKey,
        currency: currency,
        lastPaidAt: lastPaidAt,
        occurrences: occurrences,
        remind: remind ?? this.remind,
      );
}

/// Pago mensual agregado por el usuario.
class ManualRecurring {
  const ManualRecurring({
    required this.id,
    required this.name,
    required this.amountMinor,
    required this.categoryId,
    required this.dayOfMonth,
    required this.createdAt,
    this.remind = true,
    this.lastPaidMonth,
  });

  final String id;
  final String name;
  final int amountMinor;
  final String categoryId;

  /// 1–31; en meses más cortos se usa el último día.
  final int dayOfMonth;
  final bool remind;

  /// Mes (primer día) en que se registró el último pago desde Finaid.
  final DateTime? lastPaidMonth;
  final DateTime createdAt;

  /// Si la fecha del mes ya pasó hace más de esto sin registrarse el pago, se
  /// pasa al mes siguiente (el usuario lo pagó por fuera o ya no aplica).
  static const int overdueGraceDays = 20;

  static DateTime dueIn(DateTime month, int dayOfMonth) => DateTime(
        month.year,
        month.month,
        math.min(dayOfMonth, Dates.daysInMonth(month)),
      );

  DateTime nextDue(DateTime now) {
    final today = Dates.dayStart(now);
    final thisMonth = Dates.monthStart(today);
    final paidThisMonth =
        lastPaidMonth != null && Dates.sameMonth(lastPaidMonth!, thisMonth);
    final due = dueIn(thisMonth, dayOfMonth);
    if (paidThisMonth ||
        today.difference(due).inDays > overdueGraceDays) {
      return dueIn(Dates.addMonths(thisMonth, 1), dayOfMonth);
    }
    return due;
  }

  RecurringPayment toPayment(DateTime now) => RecurringPayment(
        id: id,
        name: name,
        amountMinor: amountMinor,
        categoryId: categoryId,
        nextDueAt: nextDue(now),
        source: RecurringSource.manual,
        lastPaidAt: lastPaidMonth,
        remind: remind,
      );

  ManualRecurring copyWith({
    String? name,
    int? amountMinor,
    String? categoryId,
    int? dayOfMonth,
    bool? remind,
    DateTime? lastPaidMonth,
  }) =>
      ManualRecurring(
        id: id,
        name: name ?? this.name,
        amountMinor: amountMinor ?? this.amountMinor,
        categoryId: categoryId ?? this.categoryId,
        dayOfMonth: dayOfMonth ?? this.dayOfMonth,
        createdAt: createdAt,
        remind: remind ?? this.remind,
        lastPaidMonth: lastPaidMonth ?? this.lastPaidMonth,
      );
}

/// Preferencia del usuario sobre un pago detectado.
class RecurringOverride {
  const RecurringOverride({
    required this.recurringId,
    this.dismissed = false,
    this.remind = true,
  });

  final String recurringId;

  /// "No es recurrente": no mostrarlo más.
  final bool dismissed;

  /// Avisar antes de la fecha.
  final bool remind;
}
