import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../../core/external_launch.dart';
import '../../domain/entities/bank.dart';
import '../../domain/entities/raw_notification.dart';
import '../../domain/ports/notification_source.dart';
import '../../domain/recurring/reminder_planner.dart';
import 'local_notifier.dart';

/// App que ha emitido notificaciones en este teléfono (solo package y conteo).
class SeenPackage {
  const SeenPackage({
    required this.package,
    required this.label,
    required this.count,
    required this.lastSeen,
    this.allowedNatively = false,
  });

  final String package;
  final String label;
  final int count;
  final DateTime lastSeen;

  /// El servicio nativo la está escuchando (activada o detectada como banco).
  final bool allowedNatively;

  bool get looksLikeBank => BankDetector.looksLikeBank(package, label);
}

class DeviceInfo {
  const DeviceInfo({
    required this.manufacturer,
    required this.model,
    required this.sdk,
    required this.release,
  });

  final String manufacturer;
  final String model;
  final int sdk;
  final String release;

  @override
  String toString() => '$manufacturer $model · Android $release (API $sdk)';
}

/// Estado del servicio nativo de escucha.
class ListenerStatus {
  const ListenerStatus({
    required this.permissionGranted,
    required this.listenerConnected,
    required this.batteryUnrestricted,
    required this.canPostNotifications,
  });

  final bool permissionGranted;
  final bool listenerConnected;
  final bool batteryUnrestricted;
  final bool canPostNotifications;

  bool get healthy => permissionGranted && listenerConnected;
}

/// Puente con `FinaidNotificationListenerService` (Kotlin).
///
/// * Las notificaciones que llegan con la app viva se reciben por el
///   `EventChannel`.
/// * Las que llegaron con la app cerrada quedan en una tabla SQLite nativa y se
///   recogen con `drainPending` al abrir o volver a primer plano. Antes de drenar
///   se le pide al servicio que revise la bandeja, por si el sistema lo suspendió.
class AndroidNotificationSource implements NotificationSource, LocalNotifier {
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
  Future<bool> hasPermission() => _bool('isPermissionGranted');

  @override
  Future<void> requestPermission() {
    ExternalLaunch.notify();
    return _call('openSettings');
  }

  Future<bool> isListenerConnected() => _bool('isListenerConnected');

  Future<bool> isBatteryUnrestricted() => _bool('isBatteryUnrestricted');

  Future<void> openBatterySettings() {
    ExternalLaunch.notify();
    return _call('openBatterySettings');
  }

  /// Ficha de la app en Ajustes ("Permitir ajustes restringidos", batería…).
  Future<void> openAppDetails() {
    ExternalLaunch.notify();
    return _call('openAppDetails');
  }

  /// Pantalla de "Inicio automático" del fabricante. `false` si no existe y se
  /// abrió la ficha de la app en su lugar.
  Future<bool> openAutostartSettings() {
    ExternalLaunch.notify();
    return _bool('openAutostartSettings');
  }

  @override
  Future<bool> hasPostNotificationPermission() =>
      _bool('hasPostNotificationPermission');

  @override
  Future<void> requestPostNotificationPermission() {
    ExternalLaunch.notify();
    return _call('requestPostNotificationPermission');
  }

  /// Pide al sistema volver a enlazar el servicio (útil tras conceder permiso).
  Future<void> requestRebind() => _call('requestRebind');

  Future<ListenerStatus> status() async => ListenerStatus(
        permissionGranted: await hasPermission(),
        listenerConnected: await isListenerConnected(),
        batteryUnrestricted: await isBatteryUnrestricted(),
        canPostNotifications: await hasPostNotificationPermission(),
      );

  /// Revisa las notificaciones que siguen en la bandeja. Devuelve cuántas
  /// nuevas entraron al buffer, o -1 si el servicio no está conectado.
  Future<int> scanActiveNotifications() async {
    try {
      return await _methods.invokeMethod<int>('scanActiveNotifications') ?? 0;
    } on PlatformException {
      return 0;
    } on MissingPluginException {
      return 0;
    }
  }

  @override
  Future<void> showCaptureNotification({
    required String title,
    required String body,
    bool budget = false,
    bool hideOnLockScreen = false,
  }) =>
      _call('showCaptureNotification', {
        'title': title,
        'body': body,
        'channel': budget ? 'budget' : 'captures',
        'private': hideOnLockScreen,
      });

  /// Reemplaza los recordatorios de pagos programados (ver ReminderScheduler.kt).
  @override
  Future<void> scheduleReminders(
    List<PlannedReminder> reminders, {
    bool hideOnLockScreen = false,
  }) =>
      _call('scheduleReminders', {
        'items': [
          for (final r in reminders)
            {
              'id': r.id,
              'at': r.at.millisecondsSinceEpoch,
              'title': r.title,
              'body': r.body,
              'private': hideOnLockScreen,
            },
        ],
      });

  /// Publica la notificación de autoprueba. `false` si no hay permiso de avisos.
  Future<bool> postSelfTest() => _bool('postSelfTest');

  @override
  Future<DeviceInfo?> deviceInfo() async {
    try {
      final m = await _methods.invokeMapMethod<String, dynamic>('deviceInfo');
      if (m == null) return null;
      return DeviceInfo(
        manufacturer: '${m['manufacturer'] ?? ''}',
        model: '${m['model'] ?? ''}',
        sdk: (m['sdk'] as num?)?.toInt() ?? 0,
        release: '${m['release'] ?? ''}',
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
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
    await scanActiveNotifications();
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

  Future<void> setAllowedPackages(Iterable<String> packages) =>
      _call('setAllowedPackages', {'packages': packages.toList()});

  Future<void> setDisabledPackages(Iterable<String> packages) =>
      _call('setDisabledPackages', {'packages': packages.toList()});

  Future<List<SeenPackage>> seenPackages() async {
    try {
      final list = await _methods.invokeListMethod<dynamic>('getSeenPackages');
      return [
        for (final raw in list ?? const [])
          if (raw is Map)
            SeenPackage(
              package: raw['package'] as String,
              label: (raw['label'] as String?) ?? raw['package'] as String,
              count: (raw['count'] as num?)?.toInt() ?? 0,
              lastSeen: DateTime.fromMillisecondsSinceEpoch(
                  (raw['lastSeen'] as num?)?.toInt() ?? 0),
              allowedNatively: raw['allowed'] == true,
            ),
      ];
    } on MissingPluginException {
      return const [];
    }
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _controller.close();
  }

  Future<bool> _bool(String method) async {
    try {
      return await _methods.invokeMethod<bool>(method) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> _call(String method, [Map<String, Object?>? args]) async {
    try {
      await _methods.invokeMethod<void>(method, args);
    } on MissingPluginException {
      // Plataforma sin canal (tests, escritorio).
    } on PlatformException {
      // No crítico.
    }
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
      id: m['id'] as String? ??
          '${package}_${DateTime.now().microsecondsSinceEpoch}',
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
