import '../../core/utils/text_tools.dart';

/// Perfil de una entidad financiera: cómo reconocer sus notificaciones.
class BankProfile {
  const BankProfile({
    required this.id,
    required this.name,
    required this.packages,
    required this.signatures,
    required this.color,
  });

  final String id;
  final String name;

  /// Packages Android (y en el futuro bundle ids iOS) de la app oficial.
  final List<String> packages;

  /// Fragmentos normalizados (minúsculas, sin tildes) que identifican a la
  /// entidad cuando el mensaje llega por SMS u otro canal.
  final List<String> signatures;
  final int color;
}

class KnownBanks {
  KnownBanks._();

  static const bancolombia = BankProfile(
    id: 'bancolombia',
    name: 'Bancolombia',
    packages: ['com.todo1.mobile', 'com.bancolombia.personas'],
    signatures: ['bancolombia'],
    color: 0xFFFDDA24,
  );
  static const nequi = BankProfile(
    id: 'nequi',
    name: 'Nequi',
    packages: ['com.nequi.MobileApp'],
    signatures: ['nequi'],
    color: 0xFFDA0081,
  );
  static const daviplata = BankProfile(
    id: 'daviplata',
    name: 'DaviPlata',
    packages: ['com.davivienda.daviplataapp'],
    signatures: ['daviplata'],
    color: 0xFFED1C24,
  );
  static const davivienda = BankProfile(
    id: 'davivienda',
    name: 'Davivienda',
    packages: ['com.davivienda.daviviendaapp', 'com.davivienda.mobileapp'],
    signatures: ['davivienda'],
    color: 0xFFE30613,
  );
  static const nu = BankProfile(
    id: 'nu',
    name: 'Nu',
    packages: ['com.nu.production'],
    signatures: ['nubank', 'nu colombia', 'tarjeta nu', 'cuenta nu', 'tu nu'],
    color: 0xFF820AD1,
  );
  static const bbva = BankProfile(
    id: 'bbva',
    name: 'BBVA',
    // "BBVA Colombia | Banca Móvil" en Google Play.
    packages: ['co.com.bbva.mb'],
    signatures: ['bbva'],
    color: 0xFF072146,
  );
  static const bogota = BankProfile(
    id: 'bogota',
    name: 'Banco de Bogotá',
    packages: [
      'co.com.bancodebogota.bancamovil',
      'com.bancodebogota.bancamovil',
    ],
    signatures: ['banco de bogota', 'bco de bogota'],
    color: 0xFF003DA5,
  );
  static const lulo = BankProfile(
    id: 'lulo',
    name: 'Lulo Bank',
    packages: ['co.lulobank.app', 'com.lulobank.app'],
    signatures: ['lulo bank', 'lulo'],
    color: 0xFF52F2A1,
  );
  static const rappipay = BankProfile(
    id: 'rappipay',
    name: 'RappiPay',
    packages: ['com.rappi.pay'],
    signatures: ['rappipay', 'rappi pay', 'rappicard'],
    color: 0xFFFF441F,
  );
  static const scotiabank = BankProfile(
    id: 'scotiabank',
    name: 'Scotiabank Colpatria',
    packages: ['com.scotiabankcolpatria.app', 'co.com.scotiabankcolpatria'],
    signatures: ['scotiabank', 'colpatria'],
    color: 0xFFEC111A,
  );

  /// Pagos con Apple Pay capturados por la automatización de Wallet en Atajos.
  static const applePay = BankProfile(
    id: 'applepay',
    name: 'Apple Pay',
    packages: ['ios.wallet'],
    signatures: ['apple pay'],
    color: 0xFF000000,
  );

  /// Entidad que no reconocemos; el parser genérico igual intenta extraer la
  /// transacción.
  static const unknown = BankProfile(
    id: 'desconocido',
    name: 'Banco',
    packages: [],
    signatures: [],
    color: 0xFF607D8B,
  );

  static const List<BankProfile> all = [
    bancolombia,
    nequi,
    daviplata,
    davivienda,
    nu,
    bbva,
    bogota,
    lulo,
    rappipay,
    scotiabank,
    applePay,
  ];

  /// Apps de mensajería: los bancos colombianos también avisan por SMS.
  static const List<String> smsPackages = [
    'com.google.android.apps.messaging',
    'com.samsung.android.messaging',
    'com.android.mms',
    'com.android.messaging',
  ];

  static List<String> get defaultPackages => [
        for (final b in all) ...b.packages,
        ...smsPackages,
      ];

  static BankProfile? byPackage(String package) {
    for (final b in all) {
      if (b.packages.contains(package)) return b;
    }
    return null;
  }

  static BankProfile? bySignature(String normalizedText) {
    for (final b in all) {
      for (final s in b.signatures) {
        if (normalizedText.contains(s)) return b;
      }
    }
    return null;
  }

  /// Movimientos que el usuario registra a mano.
  static const manual = BankProfile(
    id: 'manual',
    name: 'Manual',
    packages: [],
    signatures: [],
    color: 0xFF0E7C6B,
  );

  static BankProfile byId(String id) {
    if (id == manual.id) return manual;
    return all.firstWhere((b) => b.id == id, orElse: () => unknown);
  }
}

/// Reconoce apps bancarias por su package o su nombre visible, para escucharlas
/// aunque su package no esté en [KnownBanks]. Debe coincidir con
/// `BankDetector` en Kotlin (android/.../BankPackages.kt).
class BankDetector {
  BankDetector._();

  static const List<String> keywords = [
    'bbva', 'bancolombia', 'todo1', 'nequi', 'davivienda', 'daviplata', 'nubank',
    'bancodebogota', 'banco de bogota', 'lulobank', 'lulo bank', 'rappipay',
    'rappi pay', 'scotiabank', 'colpatria', 'itau', 'avvillas', 'av villas',
    'bancoomeva', 'bancodeoccidente', 'banco de occidente', 'bancopopular',
    'banco popular', 'bancofalabella', 'banco falabella', 'cajasocial',
    'caja social', 'pichincha', 'movii', 'bancoagrario', 'banco agrario',
    'finandina', 'serfinanza', 'sudameris', 'bancamia', 'coopcentral', 'uala',
    'global66', 'tpaga',
    // Genéricos
    'banco', 'bank', 'banca movil', 'bancamovil',
  ];

  static bool looksLikeBank(String package, String? label) {
    final hay = TextTools.normalize('$package ${label ?? ''}');
    return keywords.any(hay.contains);
  }
}
