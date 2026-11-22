import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;

import '../core/utils/date_utils.dart';
import '../domain/analytics/month_summary.dart';
import '../domain/categorization/categorizer.dart';
import '../domain/entities/insight.dart';
import '../domain/entities/merchant_rule.dart';
import '../domain/entities/transaction.dart';
import '../domain/insights/insight_engine.dart';
import '../domain/parsing/parser_registry.dart';
import '../domain/ports/notification_source.dart';
import '../domain/ports/repositories.dart';
import '../domain/usecases/edit_transaction.dart';
import '../domain/usecases/ingest_notification.dart';
import '../infrastructure/platform/android_notification_source.dart';
import '../infrastructure/platform/deeplink_notification_source.dart';
import '../infrastructure/platform/local_notifier.dart';
import '../infrastructure/repositories/sqflite_repositories.dart';
import '../infrastructure/settings/app_settings_store.dart';
import '../infrastructure/backup/backup_codec.dart';
import '../infrastructure/platform/document_storage.dart';
import '../domain/recurring/recurring.dart';
import '../domain/recurring/reminder_planner.dart';
import 'backup_service.dart';
import 'budget_alert_service.dart';
import 'recurring_service.dart';
import 'capture_notification_text.dart';
import 'ingestion_service.dart';

// ---------------------------------------------------------------------------
// Infraestructura (se sobreescriben en main con instancias ya inicializadas)
// ---------------------------------------------------------------------------

final databaseProvider = Provider<Database>(
    (ref) => throw UnimplementedError('Override en ProviderScope'));

final sharedPreferencesProvider = Provider<SharedPreferences>(
    (ref) => throw UnimplementedError('Override en ProviderScope'));

final transactionRepositoryProvider = Provider<TransactionRepository>(
    (ref) => SqfliteTransactionRepository(ref.watch(databaseProvider)));

final rawNotificationRepositoryProvider = Provider<RawNotificationRepository>(
    (ref) => SqfliteRawNotificationRepository(ref.watch(databaseProvider)));

final merchantRuleRepositoryProvider = Provider<MerchantRuleRepository>(
    (ref) => SqfliteMerchantRuleRepository(ref.watch(databaseProvider)));

final budgetRepositoryProvider = Provider<BudgetRepository>(
    (ref) => SqfliteBudgetRepository(ref.watch(databaseProvider)));

final settingsStoreProvider = Provider<AppSettingsStore>(
    (ref) => AppSettingsStore(ref.watch(sharedPreferencesProvider)));

// ---------------------------------------------------------------------------
// Dominio
// ---------------------------------------------------------------------------

final parserRegistryProvider =
    Provider<ParserRegistry>((ref) => ParserRegistry.standard());

final categorizerProvider =
    Provider<Categorizer>((ref) => Categorizer.standard());

final insightEngineProvider =
    Provider<InsightEngine>((ref) => InsightEngine.standard());

final ingestUseCaseProvider = Provider<IngestNotificationUseCase>(
  (ref) => IngestNotificationUseCase(
    rawNotifications: ref.watch(rawNotificationRepositoryProvider),
    transactions: ref.watch(transactionRepositoryProvider),
    merchantRules: ref.watch(merchantRuleRepositoryProvider),
    registry: ref.watch(parserRegistryProvider),
    categorizer: ref.watch(categorizerProvider),
  ),
);

final editUseCasesProvider = Provider<EditTransactionUseCases>(
  (ref) => EditTransactionUseCases(
    transactions: ref.watch(transactionRepositoryProvider),
    merchantRules: ref.watch(merchantRuleRepositoryProvider),
  ),
);

// ---------------------------------------------------------------------------
// Fuentes de notificaciones
// ---------------------------------------------------------------------------

final androidSourceProvider = Provider<AndroidNotificationSource?>(
    (ref) => Platform.isAndroid ? AndroidNotificationSource() : null);

/// Avisos locales y datos del equipo (Android e iOS). `null` en escritorio/tests.
final localNotifierProvider = Provider<LocalNotifier?>((ref) {
  if (Platform.isAndroid) return ref.watch(androidSourceProvider);
  if (Platform.isIOS) return const IosPlatformBridge();
  return null;
});

final deepLinkSourceProvider =
    Provider<DeepLinkNotificationSource>((ref) => DeepLinkNotificationSource());

final notificationSourcesProvider = Provider<List<NotificationSource>>((ref) {
  final android = ref.watch(androidSourceProvider);
  return [
    if (android != null) android,
    ref.watch(deepLinkSourceProvider),
  ];
});

final ingestionServiceProvider = Provider<IngestionService>((ref) {
  final notifier = ref.watch(localNotifierProvider);
  final service = IngestionService(
    sources: ref.watch(notificationSourcesProvider),
    ingest: ref.watch(ingestUseCaseProvider),
    onTransactionsChanged: () =>
        ref.read(transactionsProvider.notifier).reload(),
    onResumed: () {
      ref.invalidate(permissionStatusProvider);
      ref.invalidate(listenerStatusProvider);
      ref.invalidate(recurringPaymentsProvider);
      ref.read(settingsProvider.notifier).autoEnableDetectedBanks();
      ref.read(reminderSyncProvider).sync();
    },
    onNewTransaction: (transaction, inForeground) async {
      // Un cobro nuevo puede mover la fecha de un pago recurrente.
      ref.invalidate(recurringPaymentsProvider);
      unawaited(ref.read(reminderSyncProvider).sync());
      final settings = ref.read(settingsProvider);
      final budget =
          await ref.read(budgetAlertServiceProvider).check(transaction);
      final alerts = CaptureAlerts.plan(
        transaction: transaction,
        budget: budget,
        notifyCaptures: settings.notifyCaptures,
        budgetAlerts: settings.budgetAlerts,
      );
      if (inForeground) {
        // Con la app abierta solo se muestran las alertas de presupuesto.
        for (final a in alerts.where((a) => a.isBudgetAlert)) {
          ref.read(foregroundAlertProvider.notifier).show(a);
        }
      } else if (notifier != null) {
        for (final a in alerts) {
          await notifier.showCaptureNotification(
              title: a.title,
              body: a.body,
              budget: a.isBudgetAlert,
              hideOnLockScreen: settings.lockEnabled);
        }
      }
    },
    onFlaggedTransaction: (transaction, inForeground) async {
      final settings = ref.read(settingsProvider);
      if (!settings.notifyCaptures && !settings.budgetAlerts) return;
      final alert = CaptureAlerts.rejectedPurchase(transaction);
      if (inForeground) {
        ref.read(foregroundAlertProvider.notifier).show(alert);
      } else if (notifier != null) {
        await notifier.showCaptureNotification(
            title: alert.title,
            body: alert.body,
            budget: true,
            hideOnLockScreen: settings.lockEnabled);
      }
    },
  );
  ref.onDispose(service.dispose);
  return service;
});

/// `true` cuando no hace falta permiso (iOS / escritorio) o ya está concedido.
final permissionStatusProvider = FutureProvider<bool>((ref) async {
  final android = ref.watch(androidSourceProvider);
  if (android == null) return true;
  return android.hasPermission();
});

/// Estado completo del servicio nativo (solo Android; `null` en otras plataformas).
final listenerStatusProvider = FutureProvider<ListenerStatus?>((ref) async {
  final android = ref.watch(androidSourceProvider);
  if (android == null) return null;
  return android.status();
});

/// Fabricante, modelo y versión de Android (guía de batería, diagnóstico).
final deviceInfoProvider = FutureProvider<DeviceInfo?>((ref) async {
  final notifier = ref.watch(localNotifierProvider);
  if (notifier == null) return null;
  return notifier.deviceInfo();
});

/// Apps que han emitido notificaciones en este teléfono.
final seenPackagesProvider =
    FutureProvider.autoDispose<List<SeenPackage>>((ref) async {
  final android = ref.watch(androidSourceProvider);
  if (android == null) return const [];
  return android.seenPackages();
});

// ---------------------------------------------------------------------------
// Estado de la app
// ---------------------------------------------------------------------------

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(settingsStoreProvider).load();

  Future<void> completeOnboarding() =>
      _update(state.copyWith(onboardingDone: true));

  /// Guarda los ajustes tal como se cargaron (persiste la migración de
  /// packages nuevos) y los envía al servicio nativo.
  Future<void> completeLoadSync() => _update(state);

  Future<void> setPackageEnabled(String package, bool enabled) {
    final next = Set<String>.of(state.enabledPackages);
    final disabled = Set<String>.of(state.disabledPackages);
    if (enabled) {
      next.add(package);
      disabled.remove(package);
    } else {
      next.remove(package);
      disabled.add(package);
    }
    return _update(
        state.copyWith(enabledPackages: next, disabledPackages: disabled));
  }

  /// Activa las apps que han notificado y parecen bancarias (por package o
  /// nombre), salvo las que el usuario desactivó. Devuelve las activadas.
  Future<List<SeenPackage>> autoEnableDetectedBanks() async {
    final android = ref.read(androidSourceProvider);
    if (android == null) return const [];
    final List<SeenPackage> seen;
    try {
      seen = await android.seenPackages();
    } catch (_) {
      return const [];
    }
    final added = [
      for (final s in seen)
        if (s.looksLikeBank &&
            !state.enabledPackages.contains(s.package) &&
            !state.disabledPackages.contains(s.package))
          s,
    ];
    if (added.isNotEmpty) {
      await _update(state.copyWith(enabledPackages: {
        ...state.enabledPackages,
        ...added.map((s) => s.package),
      }));
    }
    return added;
  }

  Future<void> setNotifyCaptures(bool enabled) =>
      _update(state.copyWith(notifyCaptures: enabled));

  Future<void> setBudgetAlerts(bool enabled) =>
      _update(state.copyWith(budgetAlerts: enabled));

  Future<void> setLockEnabled(bool enabled) =>
      _update(state.copyWith(lockEnabled: enabled));

  Future<void> setLockTimeout(int seconds) =>
      _update(state.copyWith(lockTimeoutSeconds: seconds));

  Future<void> setRemindersEnabled(bool enabled) =>
      _update(state.copyWith(remindersEnabled: enabled));

  Future<void> setReminderDaysBefore(int days) =>
      _update(state.copyWith(reminderDaysBefore: days));

  Future<void> markBackupCreated(DateTime at) =>
      _update(state.copyWith(lastBackupAt: at));

  /// Aplica los ajustes resultantes de restaurar un respaldo.
  Future<void> applyRestored(AppSettings merged) => _update(merged);

  Future<void> setExpectedIncome(int? minor) => _update(
        minor == null || minor <= 0
            ? state.copyWith(clearExpectedIncome: true)
            : state.copyWith(expectedMonthlyIncomeMinor: minor),
      );

  /// Sincroniza la lista de packages con el servicio nativo.
  Future<void> pushToPlatform() async {
    final android = ref.read(androidSourceProvider);
    if (android == null) return;
    try {
      await android.setAllowedPackages(state.enabledPackages);
      await android.setDisabledPackages(state.disabledPackages);
    } catch (_) {
      // El canal puede no estar listo en tests o en otras plataformas.
    }
  }

  Future<void> _update(AppSettings next) async {
    state = next;
    await ref.read(settingsStoreProvider).save(next);
    await pushToPlatform();
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

class TransactionsNotifier extends AsyncNotifier<List<Transaction>> {
  @override
  Future<List<Transaction>> build() =>
      ref.watch(transactionRepositoryProvider).all();

  Future<void> reload() async {
    state = AsyncData(await ref.read(transactionRepositoryProvider).all());
  }
}

final transactionsProvider =
    AsyncNotifierProvider<TransactionsNotifier, List<Transaction>>(
        TransactionsNotifier.new);

class BudgetsNotifier extends AsyncNotifier<Map<String, int>> {
  @override
  Future<Map<String, int>> build() =>
      ref.watch(budgetRepositoryProvider).all();

  Future<void> setBudget(String categoryId, int? limitMinor) async {
    final repo = ref.read(budgetRepositoryProvider);
    if (limitMinor == null || limitMinor <= 0) {
      await repo.remove(categoryId);
    } else {
      await repo.set(categoryId, limitMinor);
    }
    state = AsyncData(await repo.all());
  }
}

final budgetsProvider =
    AsyncNotifierProvider<BudgetsNotifier, Map<String, int>>(
        BudgetsNotifier.new);

class MerchantRulesNotifier extends AsyncNotifier<List<MerchantRule>> {
  @override
  Future<List<MerchantRule>> build() =>
      ref.watch(merchantRuleRepositoryProvider).all();

  Future<void> reload() async {
    state = AsyncData(await ref.read(merchantRuleRepositoryProvider).all());
  }

  Future<void> remove(MerchantRule rule) async {
    await ref.read(merchantRuleRepositoryProvider).delete(rule.id);
    await reload();
  }
}

final merchantRulesProvider =
    AsyncNotifierProvider<MerchantRulesNotifier, List<MerchantRule>>(
        MerchantRulesNotifier.new);

class SelectedMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => Dates.monthStart(DateTime.now());

  void previous() => state = Dates.addMonths(state, -1);

  void next() {
    final candidate = Dates.addMonths(state, 1);
    if (!candidate.isAfter(Dates.monthStart(DateTime.now()))) {
      state = candidate;
    }
  }

  bool get isCurrentMonth => Dates.sameMonth(state, DateTime.now());
}

final selectedMonthProvider =
    NotifierProvider<SelectedMonthNotifier, DateTime>(
        SelectedMonthNotifier.new);

// ---------------------------------------------------------------------------
// Derivados
// ---------------------------------------------------------------------------

final allTransactionsProvider = Provider<List<Transaction>>(
    (ref) => ref.watch(transactionsProvider).valueOrNull ?? const []);

final monthSummaryProvider = Provider<MonthSummary>((ref) {
  final month = ref.watch(selectedMonthProvider);
  return MonthSummary.from(ref.watch(allTransactionsProvider), month);
});

final insightsProvider = Provider<List<Insight>>((ref) {
  final transactions = ref.watch(allTransactionsProvider);
  final budgets = ref.watch(budgetsProvider).valueOrNull ?? const {};
  final settings = ref.watch(settingsProvider);
  return ref.watch(insightEngineProvider).generate(
        transactions: transactions,
        budgets: budgets,
        expectedIncomeMinor: settings.expectedMonthlyIncomeMinor,
        lastBackupAt: settings.lastBackupAt,
      );
});

final reviewCountProvider = Provider<int>((ref) =>
    ref.watch(allTransactionsProvider).where((t) => t.needsReview).length);

// ---------------------------------------------------------------------------
// Respaldo y exportación
// ---------------------------------------------------------------------------

final backupCodecProvider = Provider<BackupCodec>((ref) => BackupCodec());

final documentStorageProvider =
    Provider<DocumentStorage>((ref) => const DocumentStorage());

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(
    transactions: ref.watch(transactionRepositoryProvider),
    merchantRules: ref.watch(merchantRuleRepositoryProvider),
    budgets: ref.watch(budgetRepositoryProvider),
    rawNotifications: ref.watch(rawNotificationRepositoryProvider),
    recurring: ref.watch(recurringRepositoryProvider),
  ),
);

// ---------------------------------------------------------------------------
// Alertas de presupuesto
// ---------------------------------------------------------------------------

final budgetAlertServiceProvider = Provider<BudgetAlertService>(
  (ref) => BudgetAlertService(
    transactions: ref.watch(transactionRepositoryProvider),
    budgets: ref.watch(budgetRepositoryProvider),
  ),
);

/// Alerta para mostrar dentro de la app (la escucha FinaidApp y la muestra
/// como SnackBar). Cada alerta lleva un número para que dos iguales seguidas
/// también se muestren.
class ForegroundAlert {
  const ForegroundAlert(this.sequence, this.alert);

  final int sequence;
  final CaptureAlert alert;
}

class ForegroundAlertNotifier extends Notifier<ForegroundAlert?> {
  var _sequence = 0;

  @override
  ForegroundAlert? build() => null;

  void show(CaptureAlert alert) => state = ForegroundAlert(++_sequence, alert);
}

final foregroundAlertProvider =
    NotifierProvider<ForegroundAlertNotifier, ForegroundAlert?>(
        ForegroundAlertNotifier.new);

// ---------------------------------------------------------------------------
// Pagos recurrentes y recordatorios
// ---------------------------------------------------------------------------

final recurringRepositoryProvider = Provider<RecurringRepository>(
    (ref) => SqfliteRecurringRepository(ref.watch(databaseProvider)));

final recurringServiceProvider = Provider<RecurringService>(
  (ref) => RecurringService(
    transactions: ref.watch(transactionRepositoryProvider),
    recurring: ref.watch(recurringRepositoryProvider),
  ),
);

/// Pagos recurrentes (detectados + manuales) ordenados por próxima fecha.
final recurringPaymentsProvider =
    FutureProvider<List<RecurringPayment>>((ref) async {
  ref.watch(transactionsProvider);
  return ref.read(recurringServiceProvider).list();
});

/// Recalcula y programa los recordatorios de pagos (AlarmManager).
class ReminderSync {
  ReminderSync(this._ref);

  final Ref _ref;

  Future<void> sync({DateTime? now}) async {
    final notifier = _ref.read(localNotifierProvider);
    if (notifier == null) return;
    try {
      final settings = _ref.read(settingsProvider);
      if (!settings.remindersEnabled) {
        await notifier.scheduleReminders(const []);
        return;
      }
      final payments = await _ref.read(recurringServiceProvider).list(now: now);
      final plan = ReminderPlanner.plan(
        payments,
        now: now ?? DateTime.now(),
        daysBefore: settings.reminderDaysBefore,
      );
      await notifier.scheduleReminders(plan,
          hideOnLockScreen: settings.lockEnabled);
    } catch (_) {
      // No crítico: se reintenta en la próxima sincronización.
    }
  }
}

final reminderSyncProvider = Provider<ReminderSync>((ref) => ReminderSync(ref));
