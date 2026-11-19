import 'package:finaid/application/app_lock.dart';
import 'package:finaid/application/providers.dart';
import 'package:finaid/infrastructure/platform/device_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAuth implements DeviceAuth {
  AuthOutcome next = AuthOutcome.success;
  int calls = 0;

  @override
  Future<DeviceAuthStatus> status() async =>
      const DeviceAuthStatus(available: true, biometric: true);

  @override
  Future<AuthOutcome> authenticate({
    String title = 'Desbloquear Finaid',
    String? subtitle,
  }) async {
    calls++;
    return next;
  }
}

void main() {
  late DateTime now;
  late FakeAuth auth;

  Future<ProviderContainer> container(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    final sp = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      deviceAuthProvider.overrideWithValue(auth),
      clockProvider.overrideWithValue(() => now),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  void away(ProviderContainer c, Duration d) {
    final lock = c.read(appLockProvider.notifier);
    lock.onBackground();
    now = now.add(d);
    lock.onForeground();
  }

  setUp(() {
    now = DateTime(2026, 11, 19, 12);
    auth = FakeAuth();
  });

  test('sin bloqueo activo nunca bloquea', () async {
    final c = await container({});
    expect(c.read(appLockProvider), isFalse);
    away(c, const Duration(hours: 2));
    expect(c.read(appLockProvider), isFalse);
  });

  test('arranca bloqueada y desbloquea con la huella', () async {
    final c = await container({'app_lock': true});
    expect(c.read(appLockProvider), isTrue);
    expect(await c.read(appLockProvider.notifier).unlock(), AuthOutcome.success);
    expect(c.read(appLockProvider), isFalse);
  });

  test('vuelve a bloquear solo tras el tiempo configurado', () async {
    final c = await container({'app_lock': true, 'app_lock_timeout': 60});
    await c.read(appLockProvider.notifier).unlock();

    away(c, const Duration(seconds: 30));
    expect(c.read(appLockProvider), isFalse);

    away(c, const Duration(seconds: 61));
    expect(c.read(appLockProvider), isTrue);
  });

  test('con tiempo 0 bloquea cada vez que se sale', () async {
    final c = await container({'app_lock': true, 'app_lock_timeout': 0});
    await c.read(appLockProvider.notifier).unlock();
    away(c, const Duration(seconds: 1));
    expect(c.read(appLockProvider), isTrue);
  });

  test('volver de una pantalla del sistema abierta por la app no bloquea', () async {
    final c = await container({'app_lock': true, 'app_lock_timeout': 0});
    final lock = c.read(appLockProvider.notifier);
    await lock.unlock();

    lock.allowNextResume();
    away(c, const Duration(minutes: 2));
    expect(c.read(appLockProvider), isFalse);

    // La excepción es de una sola vez.
    away(c, const Duration(seconds: 5));
    expect(c.read(appLockProvider), isTrue);
  });

  test('cancelar o fallar deja la app bloqueada', () async {
    final c = await container({'app_lock': true});
    auth.next = AuthOutcome.cancelled;
    expect(await c.read(appLockProvider.notifier).unlock(), AuthOutcome.cancelled);
    expect(c.read(appLockProvider), isTrue);
    auth.next = AuthOutcome.lockout;
    await c.read(appLockProvider.notifier).unlock();
    expect(c.read(appLockProvider), isTrue);
  });

  test('si el teléfono ya no tiene bloqueo, se desbloquea y se desactiva', () async {
    final c = await container({'app_lock': true});
    auth.next = AuthOutcome.unavailable;
    await c.read(appLockProvider.notifier).unlock();
    expect(c.read(appLockProvider), isFalse);
    expect(c.read(settingsProvider).lockEnabled, isFalse);
  });

  test('desactivar el bloqueo en ajustes desbloquea', () async {
    final c = await container({'app_lock': true});
    expect(c.read(appLockProvider), isTrue);
    await c.read(settingsProvider.notifier).setLockEnabled(false);
    expect(c.read(appLockProvider), isFalse);
  });

  test('cambiar otro ajuste no bloquea ni desbloquea', () async {
    final c = await container({'app_lock': true});
    await c.read(appLockProvider.notifier).unlock();
    await c.read(settingsProvider.notifier).setBudgetAlerts(false);
    expect(c.read(appLockProvider), isFalse);
  });
}
