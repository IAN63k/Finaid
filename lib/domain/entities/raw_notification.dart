/// Por dónde llegó la notificación. Cada plataforma aporta su propio canal,
/// pero todas terminan en el mismo tipo para que el resto del dominio no
/// sepa de Android ni de iOS.
enum NotificationChannel {
  /// NotificationListenerService de Android (apps bancarias).
  androidListener,

  /// Notificación de una app de SMS capturada en Android.
  sms,

  /// Automatización de Atajos en iOS que abre `finaid://ingest?...`.
  iosShortcut,

  /// Texto pegado por el usuario (simulador / depuración).
  manual,
}

extension NotificationChannelX on NotificationChannel {
  static NotificationChannel fromName(String name) =>
      NotificationChannel.values.firstWhere((c) => c.name == name,
          orElse: () => NotificationChannel.manual);
}

class RawNotification {
  const RawNotification({
    required this.id,
    required this.sourcePackage,
    required this.text,
    required this.postedAt,
    required this.channel,
    this.title,
    this.dedupeKey,
  });

  final String id;

  /// Package de Android, bundle id de iOS o un identificador lógico.
  final String sourcePackage;
  final String? title;
  final String text;
  final DateTime postedAt;
  final NotificationChannel channel;

  /// Clave estable para no ingerir dos veces la misma notificación.
  final String? dedupeKey;

  /// Package lógico de la autoprueba de captura (ver `SelfTest` en Kotlin).
  static const String selfTestPackage = 'co.finaid.selftest';

  bool get isSelfTest => sourcePackage == selfTestPackage;

  /// Título + cuerpo: es lo que miran los parsers.
  String get fullText {
    final t = title?.trim() ?? '';
    final body = text.trim();
    if (t.isEmpty) return body;
    if (body.toLowerCase().startsWith(t.toLowerCase())) return body;
    return '$t. $body';
  }
}
