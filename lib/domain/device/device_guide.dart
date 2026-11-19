/// Familias de fabricantes con ajustes de batería propios.
enum DeviceBrand {
  samsung,
  xiaomi,
  huawei,
  honor,
  oppo,
  realme,
  oneplus,
  vivo,
  motorola,
  google,
  other,
}

/// Pasos para que el sistema del fabricante no detenga la captura de
/// notificaciones en segundo plano. Los nombres de menús cambian entre
/// versiones; por eso cada guía termina con una pista de búsqueda.
class DeviceGuide {
  const DeviceGuide({
    required this.brand,
    required this.displayName,
    required this.steps,
    required this.offerAutostart,
    required this.showRestrictedSettingsTip,
  });

  final DeviceBrand brand;

  /// "Samsung", "Xiaomi", … para el título "Configura tu …".
  final String displayName;
  final List<String> steps;

  /// El fabricante tiene una pantalla de "Inicio automático" que conviene abrir.
  final bool offerAutostart;

  /// Android 13+: el acceso a notificaciones puede salir como "Ajuste
  /// restringido" si la app se instaló desde un archivo.
  final bool showRestrictedSettingsTip;

  /// Pasos para el "Ajuste restringido" de Android 13+.
  static const List<String> restrictedSettingsSteps = [
    'Abre Ajustes → Aplicaciones → Finaid (o toca "Información de la app").',
    'Toca el menú ⋮ de arriba a la derecha → "Permitir ajustes restringidos" y confirma.',
    'Vuelve a Acceso a notificaciones y activa Finaid.',
  ];

  static const String _searchTip =
      'Si no encuentras el menú, usa la búsqueda de Ajustes: "inicio automático", "batería" o "segundo plano".';

  static DeviceBrand brandOf(String manufacturer) {
    final m = manufacturer.toLowerCase().trim();
    if (m.contains('samsung')) return DeviceBrand.samsung;
    if (m.contains('xiaomi') || m.contains('redmi') || m.contains('poco')) {
      return DeviceBrand.xiaomi;
    }
    if (m.contains('huawei')) return DeviceBrand.huawei;
    if (m.contains('honor')) return DeviceBrand.honor;
    if (m.contains('oppo')) return DeviceBrand.oppo;
    if (m.contains('realme')) return DeviceBrand.realme;
    if (m.contains('oneplus')) return DeviceBrand.oneplus;
    if (m.contains('vivo') || m.contains('iqoo')) return DeviceBrand.vivo;
    if (m.contains('motorola') || m.contains('lenovo')) return DeviceBrand.motorola;
    if (m.contains('google')) return DeviceBrand.google;
    return DeviceBrand.other;
  }

  static DeviceGuide forDevice({required String manufacturer, required int sdk}) {
    final brand = brandOf(manufacturer);
    final restricted = sdk >= 33;
    DeviceGuide guide(String name, List<String> steps, {bool autostart = false}) =>
        DeviceGuide(
          brand: brand,
          displayName: name,
          steps: [...steps, _searchTip],
          offerAutostart: autostart,
          showRestrictedSettingsTip: restricted,
        );

    return switch (brand) {
      DeviceBrand.samsung => guide('Samsung', const [
          'Ajustes → Batería → Límites de uso en segundo plano → "Apps que nunca se suspenden" → agrega Finaid.',
          'En esa misma pantalla, desactiva "Suspender apps que no usas" o revisa que Finaid no esté en "Apps suspendidas".',
          'Ajustes → Aplicaciones → Finaid → Batería → "Sin restricciones".',
        ]),
      DeviceBrand.xiaomi => guide('Xiaomi', const [
          'Ajustes → Aplicaciones → Administrar aplicaciones → Finaid → activa "Inicio automático".',
          'En la misma pantalla → Ahorro de batería → "Sin restricciones".',
          'Abre las apps recientes, mantén presionada Finaid y toca el candado para que no se cierre.',
        ], autostart: true),
      DeviceBrand.huawei || DeviceBrand.honor => guide(
          brand == DeviceBrand.huawei ? 'Huawei' : 'Honor',
          const [
            'Ajustes → Batería → Inicio de aplicaciones → Finaid → "Gestionar manualmente".',
            'Activa "Inicio automático", "Inicio secundario" y "Ejecutar en segundo plano".',
            'En las apps recientes, desliza Finaid hacia abajo para bloquearla.',
          ],
          autostart: true,
        ),
      DeviceBrand.oppo || DeviceBrand.realme || DeviceBrand.oneplus => guide(
          switch (brand) {
            DeviceBrand.oppo => 'OPPO',
            DeviceBrand.realme => 'realme',
            _ => 'OnePlus',
          },
          const [
            'Ajustes → Aplicaciones → Finaid → Uso de batería → activa "Permitir actividad en segundo plano".',
            'En la misma pantalla activa "Permitir inicio automático" (o en Ajustes → Aplicaciones → Inicio automático).',
            'En las apps recientes, toca el menú de Finaid y elige "Bloquear".',
          ],
          autostart: true,
        ),
      DeviceBrand.vivo => guide('vivo', const [
          'Ajustes → Batería → Consumo de energía en segundo plano → permite Finaid.',
          'Ajustes → Aplicaciones → Permisos → Inicio automático → activa Finaid.',
          'En las apps recientes, bloquea Finaid con el candado.',
        ], autostart: true),
      DeviceBrand.motorola => guide('Motorola', const [
          'Ajustes → Aplicaciones → Finaid → Batería → "Sin restricciones".',
          'Motorola usa Android casi sin cambios: con ese paso suele bastar.',
        ]),
      DeviceBrand.google => guide('Pixel', const [
          'Ajustes → Aplicaciones → Finaid → Uso de batería de la app → "Sin restricciones".',
        ]),
      DeviceBrand.other => guide('teléfono', const [
          'Ajustes → Aplicaciones → Finaid → Batería → "Sin restricciones" (o desactiva la optimización de batería).',
          'Si tu teléfono tiene "Inicio automático" o "Apps protegidas", activa Finaid allí.',
        ], autostart: true),
    };
  }
}
