import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/bank.dart';

class AppSettings {
  const AppSettings({
    required this.onboardingDone,
    required this.enabledPackages,
  });

  final bool onboardingDone;

  /// Packages que el servicio nativo debe escuchar.
  final Set<String> enabledPackages;

  AppSettings copyWith({bool? onboardingDone, Set<String>? enabledPackages}) =>
      AppSettings(
        onboardingDone: onboardingDone ?? this.onboardingDone,
        enabledPackages: enabledPackages ?? this.enabledPackages,
      );
}

/// Preferencias ligeras (SharedPreferences). Lo pesado va a SQLite.
class AppSettingsStore {
  AppSettingsStore(this._prefs);

  final SharedPreferences _prefs;

  static const _onboardingKey = 'onboarding_done';
  static const _packagesKey = 'enabled_packages';

  AppSettings load() {
    final stored = _prefs.getStringList(_packagesKey);
    return AppSettings(
      onboardingDone: _prefs.getBool(_onboardingKey) ?? false,
      enabledPackages:
          stored == null ? KnownBanks.defaultPackages.toSet() : stored.toSet(),
    );
  }

  Future<void> save(AppSettings settings) async {
    await _prefs.setBool(_onboardingKey, settings.onboardingDone);
    await _prefs.setStringList(
        _packagesKey, settings.enabledPackages.toList()..sort());
  }
}
