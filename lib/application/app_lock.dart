import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../infrastructure/platform/device_auth.dart';
import 'providers.dart';

/// Reloj inyectable (para tests).
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final deviceAuthProvider = Provider<DeviceAuth>((ref) => const DeviceAuth());

/// Estado del bloqueo de la app: `true` = bloqueada.
///
/// * Con el bloqueo activo, la app arranca bloqueada.
/// * Al volver de segundo plano se bloquea si pasó al menos
///   `lockTimeoutSeconds` (0 = siempre).
/// * Volver de una pantalla del sistema que abrió la propia app (selector de
///   archivos, ajustes, permisos) no bloquea ([allowNextResume]).
class AppLockNotifier extends Notifier<bool> {
  DateTime? _backgroundSince;
  DateTime? _allowResumeUntil;

  /// Ventana en la que volver de una pantalla del sistema no bloquea.
  static const Duration externalLaunchGrace = Duration(minutes: 10);

  @override
  bool build() {
    ref.listen<bool>(settingsProvider.select((s) => s.lockEnabled),
        (_, enabled) {
      if (!enabled) state = false;
    });
    return ref.read(settingsProvider).lockEnabled;
  }

  bool get _enabled => ref.read(settingsProvider).lockEnabled;

  DateTime _now() => ref.read(clockProvider)();

  /// La app pasó a segundo plano.
  void onBackground() {
    _backgroundSince ??= _now();
  }

  /// La app volvió a primer plano.
  void onForeground() {
    final since = _backgroundSince;
    _backgroundSince = null;
    if (!_enabled || state || since == null) return;

    final allowUntil = _allowResumeUntil;
    _allowResumeUntil = null;
    if (allowUntil != null && _now().isBefore(allowUntil)) return;

    final timeout =
        Duration(seconds: ref.read(settingsProvider).lockTimeoutSeconds);
    if (_now().difference(since) >= timeout) state = true;
  }

  /// La próxima vuelta a primer plano no bloquea (la app abrió una pantalla
  /// del sistema).
  void allowNextResume() {
    _allowResumeUntil = _now().add(externalLaunchGrace);
  }

  /// Pide huella, rostro o PIN y desbloquea si se confirma.
  Future<AuthOutcome> unlock() async {
    final outcome = await ref.read(deviceAuthProvider).authenticate(
          title: 'Desbloquear Finaid',
          subtitle: 'Usa tu huella, rostro o el PIN del teléfono',
        );
    switch (outcome) {
      case AuthOutcome.success:
        state = false;
      case AuthOutcome.unavailable:
        // El teléfono ya no tiene bloqueo de pantalla: no tiene sentido dejar
        // al usuario por fuera de sus propios datos.
        await ref.read(settingsProvider.notifier).setLockEnabled(false);
        state = false;
      case AuthOutcome.cancelled:
      case AuthOutcome.lockout:
      case AuthOutcome.error:
        break;
    }
    return outcome;
  }
}

final appLockProvider =
    NotifierProvider<AppLockNotifier, bool>(AppLockNotifier.new);
