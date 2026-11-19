import 'package:uuid/uuid.dart';

import '../core/utils/date_utils.dart';
import '../domain/ports/repositories.dart';
import '../domain/recurring/recurring.dart';
import '../domain/recurring/recurring_detector.dart';

/// Pagos recurrentes: los detectados en el historial (menos los que el usuario
/// descartó) más los agregados a mano.
class RecurringService {
  RecurringService({
    required this.transactions,
    required this.recurring,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final TransactionRepository transactions;
  final RecurringRepository recurring;
  final Uuid _uuid;

  Future<List<RecurringPayment>> list({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final overrides = await recurring.overrides();
    final detected = RecurringDetector.detect(await transactions.all(), now: today)
        .where((p) => overrides[p.id]?.dismissed != true)
        .map((p) => p.copyWith(remind: overrides[p.id]?.remind ?? true));
    final manual = (await recurring.manual()).map((m) => m.toPayment(today));
    return [...detected, ...manual]
      ..sort((a, b) => a.nextDueAt.compareTo(b.nextDueAt));
  }

  /// "No es recurrente": el pago detectado deja de mostrarse.
  Future<void> dismiss(RecurringPayment p) => recurring.setOverride(
      RecurringOverride(recurringId: p.id, dismissed: true, remind: p.remind));

  /// Deshace [dismiss].
  Future<void> restore(RecurringPayment p) => recurring.setOverride(
      RecurringOverride(recurringId: p.id, dismissed: false, remind: p.remind));

  Future<void> setRemind(RecurringPayment p, bool remind) async {
    if (p.isManual) {
      final item = (await recurring.manual()).where((m) => m.id == p.id);
      if (item.isNotEmpty) {
        await recurring.upsertManual(item.first.copyWith(remind: remind));
      }
    } else {
      await recurring.setOverride(
          RecurringOverride(recurringId: p.id, remind: remind));
    }
  }

  Future<ManualRecurring> saveManual({
    String? id,
    required String name,
    required int amountMinor,
    required String categoryId,
    required int dayOfMonth,
    required bool remind,
    DateTime? now,
  }) async {
    final existing = id == null
        ? null
        : (await recurring.manual()).where((m) => m.id == id).firstOrNull;
    final item = existing?.copyWith(
          name: name,
          amountMinor: amountMinor,
          categoryId: categoryId,
          dayOfMonth: dayOfMonth,
          remind: remind,
        ) ??
        ManualRecurring(
          id: _uuid.v4(),
          name: name,
          amountMinor: amountMinor,
          categoryId: categoryId,
          dayOfMonth: dayOfMonth.clamp(1, 31),
          remind: remind,
          createdAt: now ?? DateTime.now(),
        );
    await recurring.upsertManual(item);
    return item;
  }

  Future<void> deleteManual(String id) => recurring.deleteManual(id);

  Future<ManualRecurring?> manualById(String id) async =>
      (await recurring.manual()).where((m) => m.id == id).firstOrNull;

  /// Marca el pago manual como hecho en el mes de [dueAt]: la próxima fecha
  /// pasa al mes siguiente.
  Future<void> markManualPaid(ManualRecurring item, DateTime dueAt) =>
      recurring.upsertManual(
          item.copyWith(lastPaidMonth: Dates.monthStart(dueAt)));
}
