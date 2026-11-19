import '../core/utils/date_utils.dart';
import '../domain/entities/bank.dart';
import '../domain/ports/repositories.dart';
import '../infrastructure/platform/android_notification_source.dart';
import '../infrastructure/settings/app_settings_store.dart';

/// Reporte de texto para depurar la captura desde el celular: estado del
/// servicio, fuentes, apps detectadas y últimas notificaciones recibidas.
/// Se copia al portapapeles para compartirlo; contiene texto de notificaciones
/// bancarias, así que el usuario decide si lo envía.
class DiagnosticsReport {
  DiagnosticsReport._();

  static String build({
    required String appVersion,
    required DateTime now,
    required AppSettings settings,
    DeviceInfo? device,
    ListenerStatus? status,
    List<SeenPackage> seen = const [],
    List<RawNotificationRecord> recent = const [],
    int maxSeen = 40,
    int maxRecent = 25,
  }) {
    final b = StringBuffer()
      ..writeln('# Diagnóstico Finaid')
      ..writeln('Versión: $appVersion')
      ..writeln('Fecha: ${Dates.shortDate(now)}')
      ..writeln('Dispositivo: ${device ?? 'desconocido'}')
      ..writeln()
      ..writeln('## Servicio');
    if (status == null) {
      b.writeln('No disponible en esta plataforma');
    } else {
      b
        ..writeln('Acceso a notificaciones: ${_yes(status.permissionGranted)}')
        ..writeln('Servicio conectado: ${_yes(status.listenerConnected)}')
        ..writeln('Batería sin restricciones: ${_yes(status.batteryUnrestricted)}')
        ..writeln('Avisos de Finaid: ${_yes(status.canPostNotifications)}');
    }

    b
      ..writeln()
      ..writeln('## Fuentes activadas (${settings.enabledPackages.length})');
    for (final p in settings.enabledPackages.toList()..sort()) {
      final bank = KnownBanks.byPackage(p);
      b.writeln('- $p${bank == null ? '' : ' (${bank.name})'}');
    }
    if (settings.disabledPackages.isNotEmpty) {
      b.writeln('Desactivadas por el usuario: '
          '${(settings.disabledPackages.toList()..sort()).join(', ')}');
    }

    b
      ..writeln()
      ..writeln('## Apps que han notificado (${seen.length})');
    for (final s in seen.take(maxSeen)) {
      final flags = [
        if (settings.enabledPackages.contains(s.package)) 'activada',
        if (settings.disabledPackages.contains(s.package)) 'desactivada',
        if (s.looksLikeBank) 'parece banco',
        if (s.allowedNatively) 'escuchada',
      ];
      b.writeln('- ${s.label} · ${s.package} · ${s.count}x · '
          'última ${Dates.shortDate(s.lastSeen)}'
          '${flags.isEmpty ? '' : ' [${flags.join(', ')}]'}');
    }

    b
      ..writeln()
      ..writeln('## Últimas notificaciones recibidas (${recent.length})');
    for (final r in recent.take(maxRecent)) {
      final n = r.notification;
      final text = n.fullText.replaceAll('\n', ' ');
      b
        ..writeln('- ${Dates.shortDate(n.postedAt)} · ${n.sourcePackage} · '
            '${r.status}${r.reason == null ? '' : ' (${r.reason})'}')
        ..writeln('  ${text.length > 300 ? '${text.substring(0, 300)}…' : text}');
    }
    return b.toString();
  }

  static String _yes(bool v) => v ? 'sí' : 'NO';
}
