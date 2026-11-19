import 'package:flutter/services.dart';

import '../../core/external_launch.dart';
import '../../domain/recurring/reminder_planner.dart';
import 'android_notification_source.dart';

/// Avisos locales y datos del equipo, comunes a Android e iOS. Ambos lados
/// nativos implementan el canal `co.finaid/notifications` con los mismos
/// métodos (Kotlin: NotificationChannels; Swift: FinaidIosPlugin).
abstract class LocalNotifier {
  Future<void> showCaptureNotification({
    required String title,
    required String body,
    bool budget = false,
    bool hideOnLockScreen = false,
  });

  Future<void> scheduleReminders(
    List<PlannedReminder> reminders, {
    bool hideOnLockScreen = false,
  });

  Future<bool> hasPostNotificationPermission();

  Future<void> requestPostNotificationPermission();

  Future<DeviceInfo?> deviceInfo();
}

/// Implementación para iOS (FinaidIosPlugin.swift). En Android se usa
/// [AndroidNotificationSource], que además escucha notificaciones.
class IosPlatformBridge implements LocalNotifier {
  const IosPlatformBridge([this._channel = const MethodChannel(channelName)]);

  static const String channelName = 'co.finaid/notifications';

  final MethodChannel _channel;

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
      });

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
            },
        ],
      });

  @override
  Future<bool> hasPostNotificationPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasPostNotificationPermission') ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> requestPostNotificationPermission() =>
      _call('requestPostNotificationPermission');

  @override
  Future<DeviceInfo?> deviceInfo() async {
    try {
      final m = await _channel.invokeMapMethod<String, dynamic>('deviceInfo');
      if (m == null) return null;
      return DeviceInfo(
        manufacturer: '${m['manufacturer'] ?? 'Apple'}',
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

  /// Abre la app Atajos para configurar las automatizaciones.
  Future<bool> openShortcuts() async {
    ExternalLaunch.notify();
    try {
      return await _channel.invokeMethod<bool>('openShortcuts') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> _call(String method, [Map<String, Object?>? args]) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on MissingPluginException {
      // Sin plugin (tests, otra plataforma).
    } on PlatformException {
      // No crítico.
    }
  }
}
