import 'package:finaid/domain/entities/bank.dart';
import 'package:finaid/infrastructure/settings/app_settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('BankDetector', () {
    test('reconoce apps bancarias por package o nombre visible', () {
      expect(BankDetector.looksLikeBank('co.com.bbva.mb', 'BBVA Colombia'), isTrue);
      expect(BankDetector.looksLikeBank('com.todo1.mobile', 'Bancolombia'), isTrue);
      expect(BankDetector.looksLikeBank('com.nequi.MobileApp', 'Nequi Colombia'),
          isTrue);
      expect(BankDetector.looksLikeBank('com.example.x', 'Banco Caja Social'), isTrue);
      expect(BankDetector.looksLikeBank('co.itau.app', 'Itaú'), isTrue);
    });

    test('no confunde apps comunes con bancos', () {
      expect(BankDetector.looksLikeBank('com.whatsapp', 'WhatsApp'), isFalse);
      expect(BankDetector.looksLikeBank(
              'com.google.android.googlequicksearchbox', 'Google'),
          isFalse);
      expect(BankDetector.looksLikeBank(
              'com.samsung.android.app.smartcapture', 'Captura de pantalla'),
          isFalse);
    });

    test('el package real de BBVA está en los valores por defecto', () {
      expect(KnownBanks.defaultPackages, contains('co.com.bbva.mb'));
      expect(KnownBanks.byPackage('co.com.bbva.mb')?.id, 'bbva');
    });
  });

  group('AppSettingsStore (migración de fuentes)', () {
    test('activa packages nuevos de una actualización sin tocar los desactivados',
        () async {
      SharedPreferences.setMockInitialValues({
        'enabled_packages': ['com.nequi.MobileApp'],
        'known_default_packages': ['com.nequi.MobileApp'],
        'disabled_packages': ['com.todo1.mobile'],
      });
      final store = AppSettingsStore(await SharedPreferences.getInstance());
      final settings = store.load();
      expect(settings.enabledPackages, contains('com.nequi.MobileApp'));
      expect(settings.enabledPackages, contains('co.com.bbva.mb'));
      expect(settings.enabledPackages, isNot(contains('com.todo1.mobile')));
      expect(settings.disabledPackages, contains('com.todo1.mobile'));
    });

    test('instalación nueva: todos los valores por defecto', () async {
      SharedPreferences.setMockInitialValues({});
      final store = AppSettingsStore(await SharedPreferences.getInstance());
      final settings = store.load();
      expect(settings.enabledPackages, KnownBanks.defaultPackages.toSet());
      expect(settings.disabledPackages, isEmpty);
    });

    test('guardar y cargar conserva desactivados y no reactiva nada', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = AppSettingsStore(prefs);
      final loaded = store.load();
      await store.save(loaded.copyWith(
        enabledPackages: {...loaded.enabledPackages}..remove('co.com.bbva.mb'),
        disabledPackages: {'co.com.bbva.mb'},
      ));
      final again = AppSettingsStore(prefs).load();
      expect(again.enabledPackages, isNot(contains('co.com.bbva.mb')));
      expect(again.disabledPackages, {'co.com.bbva.mb'});
    });
  });
}
