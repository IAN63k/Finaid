import '../entities/raw_notification.dart';

/// Origen de notificaciones. Es la única frontera con la plataforma:
///
/// * Android → `AndroidNotificationSource` (NotificationListenerService).
/// * iOS → `DeepLinkNotificationSource` alimentado por Atajos
///   (`finaid://ingest?...`), y más adelante lo que Apple permita.
///
/// El resto de la app solo consume [RawNotification].
abstract class NotificationSource {
  String get id;

  /// Si la fuente tiene sentido en esta plataforma.
  Future<bool> isAvailable();

  /// Si el usuario ya concedió el permiso necesario (si aplica).
  Future<bool> hasPermission();

  /// Lleva al usuario a conceder el permiso (si aplica).
  Future<void> requestPermission();

  /// Notificaciones que llegan mientras la app está viva.
  Stream<RawNotification> get stream;

  /// Notificaciones acumuladas mientras la app estuvo cerrada. Se consumen
  /// una sola vez.
  Future<List<RawNotification>> drainPending();

  Future<void> start();
  Future<void> dispose();
}
