import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'application/capture_notification_text.dart';
import 'application/providers.dart';
import 'infrastructure/db/app_database.dart';
import 'infrastructure/platform/android_notification_source.dart';

/// Entrypoint del motor Flutter sin interfaz que arranca
/// `BackgroundProcessor` (Kotlin) cuando llega una notificación bancaria y la
/// app no está abierta. Drena el buffer nativo, parsea, guarda y pide el aviso.
///
/// Comparte la misma base de datos y el mismo pipeline que la app en primer
/// plano; la UI recarga al volver a pantalla.
@pragma('vm:entry-point')
Future<void> backgroundMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await AppDatabase.open();
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    databaseProvider.overrideWithValue(database),
    sharedPreferencesProvider.overrideWithValue(prefs),
  ]);
  final source = AndroidNotificationSource();
  const channel = MethodChannel('co.finaid/background');

  var busy = false;
  var again = false;

  Future<void> processPending() async {
    if (busy) {
      again = true;
      return;
    }
    busy = true;
    try {
      do {
        again = false;
        final pending = await source.drainPending();
        if (pending.isEmpty) continue;
        final ingest = container.read(ingestUseCaseProvider);
        final settings = container.read(settingsStoreProvider).load();
        for (final n in pending) {
          try {
            final result = await ingest(n);
            if (result.isNewTransaction && settings.notifyCaptures) {
              final text = CaptureNotificationText.of(result.transaction!);
              await source.showCaptureNotification(
                  title: text.title, body: text.body);
            }
          } catch (e, st) {
            debugPrint('Finaid(bg): error ingiriendo: $e\n$st');
          }
        }
      } while (again);
    } finally {
      busy = false;
    }
  }

  channel.setMethodCallHandler((call) async {
    if (call.method == 'processPending') {
      await processPending();
    }
    return null;
  });
  await channel.invokeMethod<void>('ready');
}
