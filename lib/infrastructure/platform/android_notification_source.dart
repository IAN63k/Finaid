import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../../domain/entities/bank.dart';
import '../../domain/entities/raw_notification.dart';
import '../../domain/ports/notification_source.dart';

/// Puente con `FinaidNotificationListenerService` (Kotlin).
///
/// * Las notificaciones que llegan con la app viva se reciben por el
///   `EventChannel`.
/// * Las que llegaron con la app cerrada quedan en una tabla SQLite nativa y se
///   recogen con `drainPending` al abrir o volver a primer plano.
class AndroidNotificationSource implements NotificationSource {
  AndroidNotificationSource({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _methods = methodChannel ?? const MethodChannel(methodChannelName),
        _events = eventChannel ?? const EventChannel(eventChannelName);

  static const String methodChannelName = 'co.finaid/notifications';
  static const String eventChannelName = 'co.finaid/notifications/events';

  final MethodChannel _methods;
  final EventChannel _events;
  final StreamController<RawNotification> _controller =
      StreamController.broadcast();
  StreamSubscription<dynamic>? _subscription;

  @override
  String get id => 'android_listener';

  @override
  Future<bool> isAvailable() async => Platform.isAndroid;

  @override
  Future<bool> hasPermission() async {
    try {
      return await _methods.invokeMethod<bool>('isPermissionGranted') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> requestPermission() => _methods.invokeMethod('openSettings');

  /// Pide al sistema volver a enlazar el servicio (útil tras conceder permiso).
  Future<void> requestRebind() async {
    try {
      await _methods.invokeMethod('requestRebind');
    } on PlatformException {
      // No crítico.
    }
  }

  @override
  Stream<RawNotification> get stream => _controller.stream;

  @override
  Future<void> start() async {
    _subscription ??= _events.receiveBroadcastStream().listen(
      (event) {
        final n = fromPlatformMap(event);
        if (n != null) _controller.add(n);
      },
      onError: (Object _) {},
    );
  }

  @override
  Future<List<RawNotification>> drainPending() async {
    try {
      final list = await _methods.invokeListMethod<dynamic>('drainPending');
      return (list ?? const [])
          .map(fromPlatformMap)
          .whereType<RawNotification>()
          .toList();
    } on MissingPluginException {
      return const [];
    }
  }

  Future<List<String>> getAllowedPackages() async {
    final list = await _methods.invokeListMethod<String>('getAllowedPackages');
    return list ?? const [];
  }

  Future<void> setAllowedPackages(Iterable<String> packages) => _methods
      .invokeMethod('setAllowedPackages', {'packages': packages.toList()});

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _controller.close();
  }

  static RawNotification? fromPlatformMap(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final text = (m['text'] as String?)?.trim() ?? '';
    final package = m['package'] as String? ?? '';
    if (text.isEmpty || package.isEmpty) return null;
    final postedAt = m['postedAt'];
    final channel = KnownBanks.smsPackages.contains(package)
        ? NotificationChannel.sms
        : NotificationChannel.androidListener;
    return RawNotification(
      id: m['id'] as String? ?? '${package}_${DateTime.now().microsecondsSinceEpoch}',
      sourcePackage: package,
      title: m['title'] as String?,
      text: text,
      postedAt: postedAt is int
          ? DateTime.fromMillisecondsSinceEpoch(postedAt)
          : DateTime.now(),
      channel: channel,
      dedupeKey: m['dedupeKey'] as String?,
    );
  }
}
