import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/bank.dart';

class AppSettings {
  const AppSettings({
    required this.onboardingDone,
    required this.enabledPackages,
    this.notifyCaptures = true,
    this.expectedMonthlyIncomeMinor,
  });

  final bool onboardingDone;

  /// Packages que el servicio nativo debe escuchar.
  final Set<String> enabledPackages;

  /// Mostrar un aviso de Finaid cada vez que registra un movimiento.
  final bool notifyCaptures;

  /// Ingreso mensual estimado (unidades menores). Se usa en los consejos cuando
  /// el banco no notifica los ingresos.
  final int? expectedMonthlyIncomeMinor;

  AppSettings copyWith({
    bool? onboardingDone,
    Set<String>? enabledPackages,
    bool? notifyCaptures,
    int? expectedMonthlyIncomeMinor,
    bool clearExpectedIncome = false,
  }) =>
      AppSettings(
        onboardingDone: onboardingDone ?? this.onboardingDone,
        enabledPackages: enabledPackages ?? this.enabledPackages,
        notifyCaptures: notifyCaptures ?? this.notifyCaptures,
        expectedMonthlyIncomeMinor: clearExpectedIncome
            ? null
            : expectedMonthlyIncomeMinor ?? this.expectedMonthlyIncomeMinor,
      );
}

/// Preferencias ligeras (SharedPreferences). Lo pesado va a SQLite.
class AppSettingsStore {
  AppSettingsStore(this._prefs);

  final SharedPreferences _prefs;

  static const _onboardingKey = 'onboarding_done';
  static const _packagesKey = 'enabled_packages';
  static const _notifyKey = 'notify_captures';
  static const _incomeKey = 'expected_income_minor';

  AppSettings load() {
    final stored = _prefs.getStringList(_packagesKey);
    final income = _prefs.getInt(_incomeKey);
    return AppSettings(
      onboardingDone: _prefs.getBool(_onboardingKey) ?? false,
      enabledPackages:
          stored == null ? KnownBanks.defaultPackages.toSet() : stored.toSet(),
      notifyCaptures: _prefs.getBool(_notifyKey) ?? true,
      expectedMonthlyIncomeMinor: income == null || income <= 0 ? null : income,
    );
  }

  Future<void> save(AppSettings settings) async {
    await _prefs.setBool(_onboardingKey, settings.onboardingDone);
    await _prefs.setStringList(
        _packagesKey, settings.enabledPackages.toList()..sort());
    await _prefs.setBool(_notifyKey, settings.notifyCaptures);
    final income = settings.expectedMonthlyIncomeMinor;
    if (income == null) {
      await _prefs.remove(_incomeKey);
    } else {
      await _prefs.setInt(_incomeKey, income);
    }
  }
}
