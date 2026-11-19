import 'package:finaid/application/diagnostics_report.dart';
import 'package:finaid/domain/ports/repositories.dart';
import 'package:finaid/infrastructure/platform/android_notification_source.dart';
import 'package:finaid/infrastructure/settings/app_settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fixtures.dart';

void main() {
  test('el diagnóstico incluye servicio, fuentes, apps y notificaciones', () {
    final report = DiagnosticsReport.build(
      appVersion: 'Finaid 0.3.0',
      now: DateTime(2026, 11, 19, 10),
      settings: const AppSettings(
        onboardingDone: true,
        enabledPackages: {'co.com.bbva.mb'},
        disabledPackages: {'com.whatsapp'},
      ),
      device: const DeviceInfo(
          manufacturer: 'samsung', model: 'SM-S948B', sdk: 36, release: '16'),
      status: const ListenerStatus(
        permissionGranted: true,
        listenerConnected: false,
        batteryUnrestricted: true,
        canPostNotifications: true,
      ),
      seen: [
        SeenPackage(
          package: 'co.com.bbva.mb',
          label: 'BBVA Colombia',
          count: 3,
          lastSeen: DateTime(2026, 11, 17, 0, 39),
          allowedNatively: true,
        ),
      ],
      recent: [
        RawNotificationRecord(
          notification: raw(
            package: Samples.bbvaPackage,
            title: Samples.bbvaCompraTitle,
            text: Samples.bbvaCompra,
          ),
          status: 'parsed',
        ),
      ],
    );
    expect(report, contains('Finaid 0.3.0'));
    expect(report, contains('samsung SM-S948B'));
    expect(report, contains('Servicio conectado: NO'));
    expect(report, contains('co.com.bbva.mb (BBVA)'));
    expect(report, contains('BBVA Colombia · co.com.bbva.mb · 3x'));
    expect(report, contains('parece banco'));
    expect(report, contains('Desactivadas por el usuario: com.whatsapp'));
    expect(report, contains('realizaste una compra por'));
  });
}
