import 'dart:math' as math;

import '../../core/utils/date_utils.dart';
import '../../core/utils/text_tools.dart';
import '../entities/transaction.dart';
import 'recurring.dart';

/// Encuentra pagos mensuales en el historial: mismo comercio, monto parecido y
/// unos 30 días entre cobros. Sirve para suscripciones, servicios, cuotas o
/// un arriendo que se transfiere a la misma persona.
class RecurringDetector {
  RecurringDetector._();

  static const int minIntervalDays = 25;
  static const int maxIntervalDays = 35;

  /// Si el último cobro tiene más de esto, se considera cancelado.
  static const int inactiveAfterDays = 45;

  /// Montos "parecidos": hasta 15% o $2.000 de diferencia (cambios de tarifa,
  /// impuestos, consumo variable de servicios).
  static const double amountTolerance = 0.15;
  static const int amountToleranceMinor = 2000 * 100;

  static const _kinds = {
    TransactionKind.purchase,
    TransactionKind.billPayment,
    TransactionKind.transferOut,
  };

  static List<RecurringPayment> detect(
    Iterable<Transaction> transactions, {
    required DateTime now,
  }) {
    final since = now.subtract(const Duration(days: 400));
    final byMerchant = <String, List<Transaction>>{};
    for (final t in transactions) {
      if (!t.countsAsExpense || !_kinds.contains(t.kind)) continue;
      if (t.merchantKey.isEmpty || t.occurredAt.isBefore(since)) continue;
      byMerchant.putIfAbsent(t.merchantKey, () => []).add(t);
    }

    final out = <RecurringPayment>[];
    for (final entry in byMerchant.entries) {
      final clusters = _clusterByAmount(entry.value);
      for (var i = 0; i < clusters.length; i++) {
        final found = _evaluate(
          clusters[i],
          id: i == 0 ? 'auto:${entry.key}' : 'auto:${entry.key}#${i + 1}',
          now: now,
        );
        if (found != null) out.add(found);
      }
    }
    out.sort((a, b) => a.nextDueAt.compareTo(b.nextDueAt));
    return out;
  }

  static bool similar(int a, int b) {
    final diff = (a - b).abs();
    return diff <= amountToleranceMinor ||
        diff <= math.max(a, b) * amountTolerance;
  }

  /// Separa cobros del mismo comercio con montos distintos (p. ej. Google One
  /// y YouTube Premium). Grupos ordenados del más grande al más chico.
  static List<List<Transaction>> _clusterByAmount(List<Transaction> txs) {
    final sorted = [...txs]..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    final clusters = <List<Transaction>>[];
    for (final t in sorted) {
      final target = clusters.where((c) => similar(c.last.amountMinor, t.amountMinor));
      if (target.isEmpty) {
        clusters.add([t]);
      } else {
        target.first.add(t);
      }
    }
    // Orden determinista (los ids dependen de él): más cobros primero y, a
    // igualdad, el que empezó antes.
    clusters.sort((a, b) {
      final byLength = b.length.compareTo(a.length);
      if (byLength != 0) return byLength;
      return a.first.occurredAt.compareTo(b.first.occurredAt);
    });
    return clusters;
  }

  static RecurringPayment? _evaluate(
    List<Transaction> txs, {
    required String id,
    required DateTime now,
  }) {
    if (txs.length < 2) return null;
    final last = txs.last;
    if (now.difference(last.occurredAt).inDays > inactiveAfterDays) return null;

    // Al menos dos tercios de los intervalos deben ser mensuales (tolera un
    // cobro duplicado o un mes en que se pagó tarde).
    var monthly = 0;
    for (var i = 1; i < txs.length; i++) {
      final gap = Dates.dayStart(txs[i].occurredAt)
          .difference(Dates.dayStart(txs[i - 1].occurredAt))
          .inDays;
      if (gap >= minIntervalDays && gap <= maxIntervalDays) monthly++;
    }
    final intervals = txs.length - 1;
    if (monthly == 0 || monthly * 3 < intervals * 2) return null;

    // Próximo cobro: el mismo día del mes siguiente al último.
    final lastMonth = Dates.monthStart(last.occurredAt);
    var next = ManualRecurring.dueIn(
        Dates.addMonths(lastMonth, 1), last.occurredAt.day);
    // Si ya pasó sin llegar el cobro, se mantiene unos días como "pendiente".
    if (Dates.dayStart(now).difference(next).inDays > 7) {
      next = ManualRecurring.dueIn(
          Dates.addMonths(Dates.monthStart(next), 1), last.occurredAt.day);
    }

    return RecurringPayment(
      id: id,
      name: last.merchantRaw.isEmpty
          ? TextTools.titleCase(last.merchantKey)
          : TextTools.titleCase(TextTools.merchantKey(last.merchantRaw)),
      merchantKey: last.merchantKey,
      amountMinor: last.amountMinor,
      currency: last.currency,
      categoryId: last.categoryId,
      nextDueAt: next,
      source: RecurringSource.detected,
      lastPaidAt: last.occurredAt,
      occurrences: txs.length,
    );
  }
}
