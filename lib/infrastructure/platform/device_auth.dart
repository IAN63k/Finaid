import 'package:flutter/services.dart';

import '../../core/external_launch.dart';

enum AuthOutcome { success, cancelled, lockout, error, unavailable }

class DeviceAuthStatus {
  const DeviceAuthStatus({required this.available, required this.biometric});

  /// El teléfono tiene un bloqueo de pantalla seguro (PIN, patrón, contraseña).
  final bool available;

  /// Hay huella o rostro registrados.
  final bool biometric;
}

/// Huella, rostro o PIN del teléfono (ver AuthChannel.kt).
class DeviceAuth {
  const DeviceAuth([this._channel = const MethodChannel(channelName)]);

  static const String channelName = 'co.finaid/auth';

  final MethodChannel _channel;

  Future<DeviceAuthStatus> status() async {
    try {
      final m = await _channel.invokeMapMethod<String, dynamic>('status');
      return DeviceAuthStatus(
        available: m?['available'] == true,
        biometric: m?['biometric'] == true,
      );
    } on MissingPluginException {
      return const DeviceAuthStatus(available: false, biometric: false);
    } on PlatformException {
      return const DeviceAuthStatus(available: false, biometric: false);
    }
  }

  Future<AuthOutcome> authenticate({
    String title = 'Desbloquear Finaid',
    String? subtitle,
  }) async {
    // En Android 7–9 se abre una pantalla del sistema para el PIN.
    ExternalLaunch.notify();
    try {
      final r = await _channel.invokeMethod<String>(
          'authenticate', {'title': title, 'subtitle': subtitle});
      return switch (r) {
        'success' => AuthOutcome.success,
        'cancelled' => AuthOutcome.cancelled,
        'lockout' => AuthOutcome.lockout,
        'unavailable' => AuthOutcome.unavailable,
        _ => AuthOutcome.error,
      };
    } on MissingPluginException {
      return AuthOutcome.unavailable;
    } on PlatformException {
      return AuthOutcome.error;
    }
  }
}
