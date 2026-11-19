import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/bank.dart';

class AppSettings {
  const AppSettings({
    required this.onboardingDone,
    required this.enabledPackages,
    this.disabledPackages = const {},
    this.notifyCaptures = true,
    this.budgetAlerts = true,
    this.expectedMonthlyIncomeMinor,
    this.lastBackupAt,
  });

  final bool onboardingDone;

  /// Packages que el servicio nativo debe escuchar.
  final Set<String> enabledPackages;

  /// Packages que el usuario desactivó explícitamente. Ganan sobre los
  /// valores por defecto y sobre la detección automática de apps bancarias.
  final Set<String> disabledPackages;

  /// Mostrar un aviso de Finaid cada vez que registra un movimiento.
  final bool notifyCaptures;

  /// Avisar al cruzar el 80% y el 100% del presupuesto de una categoría.
  final bool budgetAlerts;

  /// Ingreso mensual estimado (unidades menores). Se usa en los consejos cuando
  /// el banco no notifica los ingresos.
  final int? expectedMonthlyIncomeMinor;

  /// Cuándo se creó el último respaldo (para recordarlo en Consejos).
  final DateTime? lastBackupAt;

  AppSettings copyWith({
    bool? onboardingDone,
    Set<String>? enabledPackages,
    Set<String>? disabledPackages,
    bool? notifyCaptures,
    bool? budgetAlerts,
    int? expectedMonthlyIncomeMinor,
    bool clearExpectedIncome = false,
    DateTime? lastBackupAt,
  }) =>
      AppSettings(
        onboardingDone: onboardingDone ?? this.onboardingDone,
        enabledPackages: enabledPackages ?? this.enabledPackages,
        disabledPackages: disabledPackages ?? this.disabledPackages,
        notifyCaptures: notifyCaptures ?? this.notifyCaptures,
        budgetAlerts: budgetAlerts ?? this.budgetAlerts,
        expectedMonthlyIncomeMinor: clearExpectedIncome
            ? null
            : expectedMonthlyIncomeMinor ?? this.expectedMonthlyIncomeMinor,
        lastBackupAt: lastBackupAt ?? this.lastBackupAt,
      );
}

/// Preferencias ligeras (SharedPreferences). Lo pesado va a SQLite.
class AppSettingsStore {
  AppSettingsStore(this._prefs);

  final SharedPreferences _prefs;

  static const _onboardingKey = 'onboarding_done';
  static const _packagesKey = 'enabled_packages';
  static const _disabledKey = 'disabled_packages';
  static const _knownDefaultsKey = 'known_default_packages';
  static const _notifyKey = 'notify_captures';
  static const _budgetAlertsKey = 'budget_alerts';
  static const _incomeKey = 'expected_income_minor';
  static const _lastBackupKey = 'last_backup_at';

  /// Carga los ajustes. Los packages que se agregan a [KnownBanks] en una
  /// actualización (p. ej. el package real de BBVA) se activan solos, salvo que
  /// el usuario los haya desactivado.
  AppSettings load() {
    final stored = _prefs.getStringList(_packagesKey);
    final disabled = (_prefs.getStringList(_disabledKey) ?? const []).toSet();
    final known = (_prefs.getStringList(_knownDefaultsKey) ?? const []).toSet();
    final defaults = KnownBanks.defaultPackages.toSet();

    final Set<String> enabled;
    if (stored == null) {
      enabled = defaults.difference(disabled);
    } else {
      final newDefaults = defaults.difference(known).difference(disabled);
      enabled = {...stored, ...newDefaults};
    }

    final income = _prefs.getInt(_incomeKey);
    return AppSettings(
      onboardingDone: _prefs.getBool(_onboardingKey) ?? false,
      enabledPackages: enabled,
      disabledPackages: disabled,
      notifyCaptures: _prefs.getBool(_notifyKey) ?? true,
      budgetAlerts: _prefs.getBool(_budgetAlertsKey) ?? true,
      expectedMonthlyIncomeMinor: income == null || income <= 0 ? null : income,
      lastBackupAt: _date(_prefs.getInt(_lastBackupKey)),
    );
  }

  Future<void> save(AppSettings settings) async {
    await _prefs.setBool(_onboardingKey, settings.onboardingDone);
    await _prefs.setStringList(
        _packagesKey, settings.enabledPackages.toList()..sort());
    await _prefs.setStringList(
        _disabledKey, settings.disabledPackages.toList()..sort());
    await _prefs.setStringList(
        _knownDefaultsKey, KnownBanks.defaultPackages.toList()..sort());
    await _prefs.setBool(_notifyKey, settings.notifyCaptures);
    await _prefs.setBool(_budgetAlertsKey, settings.budgetAlerts);
    final backup = settings.lastBackupAt;
    if (backup != null) {
      await _prefs.setInt(_lastBackupKey, backup.millisecondsSinceEpoch);
    }
    final income = settings.expectedMonthlyIncomeMinor;
    if (income == null) {
      await _prefs.remove(_incomeKey);
    } else {
      await _prefs.setInt(_incomeKey, income);
    }
  }
}

DateTime? _date(int? millis) =>
    millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
