import 'package:finaid/domain/device/device_guide.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reconoce los fabricantes por su nombre de Build.MANUFACTURER', () {
    expect(DeviceGuide.brandOf('samsung'), DeviceBrand.samsung);
    expect(DeviceGuide.brandOf('Xiaomi'), DeviceBrand.xiaomi);
    expect(DeviceGuide.brandOf('Redmi'), DeviceBrand.xiaomi);
    expect(DeviceGuide.brandOf('POCO'), DeviceBrand.xiaomi);
    expect(DeviceGuide.brandOf('HUAWEI'), DeviceBrand.huawei);
    expect(DeviceGuide.brandOf('HONOR'), DeviceBrand.honor);
    expect(DeviceGuide.brandOf('OPPO'), DeviceBrand.oppo);
    expect(DeviceGuide.brandOf('realme'), DeviceBrand.realme);
    expect(DeviceGuide.brandOf('OnePlus'), DeviceBrand.oneplus);
    expect(DeviceGuide.brandOf('vivo'), DeviceBrand.vivo);
    expect(DeviceGuide.brandOf('motorola'), DeviceBrand.motorola);
    expect(DeviceGuide.brandOf('Google'), DeviceBrand.google);
    expect(DeviceGuide.brandOf('Nokia'), DeviceBrand.other);
    expect(DeviceGuide.brandOf(''), DeviceBrand.other);
  });

  test('Samsung: pasos de One UI, sin pantalla de inicio automático', () {
    final g = DeviceGuide.forDevice(manufacturer: 'samsung', sdk: 37);
    expect(g.displayName, 'Samsung');
    expect(g.offerAutostart, isFalse);
    expect(g.steps.first, contains('Apps que nunca se suspenden'));
    expect(g.steps.last, contains('búsqueda de Ajustes'));
    expect(g.showRestrictedSettingsTip, isTrue);
  });

  test('Xiaomi y Motorola tienen sus propios pasos', () {
    final xiaomi = DeviceGuide.forDevice(manufacturer: 'Xiaomi', sdk: 34);
    expect(xiaomi.offerAutostart, isTrue);
    expect(xiaomi.steps.first, contains('Inicio automático'));

    final moto = DeviceGuide.forDevice(manufacturer: 'motorola', sdk: 31);
    expect(moto.displayName, 'Motorola');
    expect(moto.offerAutostart, isFalse);
    expect(moto.steps.first, contains('Sin restricciones'));
    expect(moto.showRestrictedSettingsTip, isFalse,
        reason: 'el ajuste restringido existe desde Android 13 (API 33)');
  });

  test('todas las marcas tienen al menos un paso y la pista de búsqueda', () {
    for (final m in const [
      'samsung', 'xiaomi', 'huawei', 'honor', 'oppo', 'realme', 'oneplus',
      'vivo', 'motorola', 'google', 'otro',
    ]) {
      final g = DeviceGuide.forDevice(manufacturer: m, sdk: 34);
      expect(g.steps.length, greaterThanOrEqualTo(2), reason: m);
      expect(g.displayName, isNotEmpty, reason: m);
    }
    expect(DeviceGuide.restrictedSettingsSteps[1], contains('Permitir ajustes restringidos'));
  });
}
