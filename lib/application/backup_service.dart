import '../domain/backup/backup_payload.dart';
import '../domain/ports/repositories.dart';
import '../infrastructure/settings/app_settings_store.dart';

/// Resultado de restaurar un respaldo.
class RestoreSummary {
  const RestoreSummary({
    required this.transactions,
    required this.merchantRules,
    required this.budgets,
    required this.notifications,
    required this.settings,
  });

  final int transactions;
  final int merchantRules;
  final int budgets;
  final int notifications;

  /// Ajustes resultantes de combinar los actuales con los del respaldo.
  final AppSettings settings;
}

/// Reúne todo lo de Finaid en un [BackupPayload] y lo restaura combinando con
/// lo que ya hay. Restaurar es idempotente: los registros se identifican por su
/// id, así que restaurar dos veces el mismo archivo no duplica nada.
class BackupService {
  BackupService({
    required this.transactions,
    required this.merchantRules,
    required this.budgets,
    required this.rawNotifications,
    this.recurring,
  });

  final TransactionRepository transactions;
  final MerchantRuleRepository merchantRules;
  final BudgetRepository budgets;
  final RawNotificationRepository rawNotifications;
  final RecurringRepository? recurring;

  /// Límite de notificaciones crudas incluidas (las más recientes).
  static const int maxNotifications = 5000;

  Future<BackupPayload> collect({
    required AppSettings settings,
    required String appVersion,
    DateTime? now,
  }) async {
    return BackupPayload(
      createdAt: now ?? DateTime.now(),
      appVersion: appVersion,
      transactions: await transactions.all(),
      merchantRules: await merchantRules.all(),
      budgets: await budgets.all(),
      notifications: await rawNotifications.recent(limit: maxNotifications),
      manualRecurring: await recurring?.manual() ?? const [],
      recurringOverrides:
          (await recurring?.overrides())?.values.toList() ?? const [],
      settings: BackupSettings(
        notifyCaptures: settings.notifyCaptures,
        expectedMonthlyIncomeMinor: settings.expectedMonthlyIncomeMinor,
        enabledPackages: settings.enabledPackages.toList()..sort(),
        disabledPackages: settings.disabledPackages.toList()..sort(),
      ),
    );
  }

  /// Combina el respaldo con los datos actuales. En conflictos de ajustes y
  /// presupuestos gana lo que ya está en este teléfono.
  Future<RestoreSummary> restore(
    BackupPayload payload, {
    required AppSettings current,
  }) async {
    await transactions.saveAll(payload.transactions);

    for (final rule in payload.merchantRules) {
      await merchantRules.upsert(rule);
    }

    final existingBudgets = await budgets.all();
    var budgetsAdded = 0;
    for (final e in payload.budgets.entries) {
      if (existingBudgets.containsKey(e.key)) continue;
      await budgets.set(e.key, e.value);
      budgetsAdded++;
    }

    for (final record in payload.notifications) {
      await rawNotifications.save(record.notification);
      await rawNotifications.markProcessed(record.notification.id,
          status: record.status, reason: record.reason);
    }

    final rec = recurring;
    if (rec != null) {
      for (final m in payload.manualRecurring) {
        await rec.upsertManual(m);
      }
      final existing = await rec.overrides();
      for (final o in payload.recurringOverrides) {
        if (!existing.containsKey(o.recurringId)) await rec.setOverride(o);
      }
    }

    final s = payload.settings;
    final enabled = {
      ...current.enabledPackages,
      ...s.enabledPackages.where((p) => !current.disabledPackages.contains(p)),
    };
    final disabled = {
      ...current.disabledPackages,
      ...s.disabledPackages.where((p) => !current.enabledPackages.contains(p)),
    };
    final merged = current.copyWith(
      enabledPackages: enabled,
      disabledPackages: disabled,
      expectedMonthlyIncomeMinor:
          current.expectedMonthlyIncomeMinor ?? s.expectedMonthlyIncomeMinor,
    );

    return RestoreSummary(
      transactions: payload.transactions.length,
      merchantRules: payload.merchantRules.length,
      budgets: budgetsAdded,
      notifications: payload.notifications.length,
      settings: merged,
    );
  }
}
