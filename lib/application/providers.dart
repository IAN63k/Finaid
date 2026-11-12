import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

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
import '../infrastructure/repositories/sqflite_repositories.dart';
import '../infrastructure/settings/app_settings_store.dart';
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
  final service = IngestionService(
    sources: ref.watch(notificationSourcesProvider),
    ingest: ref.watch(ingestUseCaseProvider),
    onTransactionsChanged: () =>
        ref.read(transactionsProvider.notifier).reload(),
    onResumed: () => ref.invalidate(permissionStatusProvider),
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

// ---------------------------------------------------------------------------
// Estado de la app
// ---------------------------------------------------------------------------

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(settingsStoreProvider).load();

  Future<void> completeOnboarding() =>
      _update(state.copyWith(onboardingDone: true));

  Future<void> setPackageEnabled(String package, bool enabled) {
    final next = Set<String>.of(state.enabledPackages);
    if (enabled) {
      next.add(package);
    } else {
      next.remove(package);
    }
    return _update(state.copyWith(enabledPackages: next));
  }

  /// Sincroniza la lista de packages con el servicio nativo.
  Future<void> pushToPlatform() async {
    final android = ref.read(androidSourceProvider);
    if (android == null) return;
    try {
      await android.setAllowedPackages(state.enabledPackages);
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
  return ref.watch(insightEngineProvider).generate(
        transactions: transactions,
        budgets: budgets,
      );
});

final reviewCountProvider = Provider<int>((ref) =>
    ref.watch(allTransactionsProvider).where((t) => t.needsReview).length);
