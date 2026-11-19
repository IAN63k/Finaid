import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/diagnostics_report.dart';
import '../../application/providers.dart';
import '../../core/utils/money_format.dart';
import '../../domain/entities/raw_notification.dart';
import '../../domain/usecases/ingest_notification.dart';
import '../widgets/ignore_reason_label.dart';
import '../../core/app_info.dart';

/// Autoprueba de extremo a extremo: Finaid publica una notificación de prueba,
/// el servicio nativo la captura, Dart la parsea y se muestra el resultado.
/// No crea movimientos.
Future<void> runCaptureSelfTest(BuildContext context, WidgetRef ref) async {
  final android = ref.read(androidSourceProvider);
  if (android == null) return;
  final messenger = ScaffoldMessenger.of(context);
  final service = ref.read(ingestionServiceProvider);
  final startedAt = DateTime.now();

  // Suscribirse antes de publicar para no perder el evento.
  final pendingResult = service.selfTestResults.first
      .timeout(const Duration(seconds: 10));

  final posted = await android.postSelfTest();
  if (!posted) {
    unawaited(pendingResult.then((_) {}, onError: (_) {}));
    messenger.showSnackBar(const SnackBar(
        content: Text(
            'Permite los avisos de Finaid para hacer la prueba (Ajustes → Avisos de Finaid).')));
    return;
  }
  messenger.showSnackBar(const SnackBar(
      duration: Duration(seconds: 3),
      content: Text('Prueba enviada; esperando a que el servicio la capture…')));

  IngestResult? result;
  try {
    result = await pendingResult;
  } on TimeoutException {
    // Pudo procesarla el motor en segundo plano: revisar el registro.
    await service.drainAll();
    final recent =
        await ref.read(rawNotificationRepositoryProvider).recent(limit: 10);
    final found = recent.where((r) =>
        r.notification.sourcePackage == RawNotification.selfTestPackage &&
        !r.notification.postedAt
            .isBefore(startedAt.subtract(const Duration(seconds: 2))));
    if (found.isNotEmpty) {
      result = IngestResult.selfTest(
          ref.read(parserRegistryProvider).parse(found.first.notification));
    }
  }
  ref.invalidate(listenerStatusProvider);
  if (!context.mounted) return;

  final outcome = result?.selfTestOutcome;
  final ok = outcome != null && outcome.isTransaction;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(ok ? Icons.check_circle : Icons.error_outline,
          color: ok ? Colors.green : Theme.of(ctx).colorScheme.error),
      title: Text(ok
          ? 'La captura funciona'
          : result == null
              ? 'El servicio no recibió la prueba'
              : 'Llegó, pero no se entendió'),
      content: Text(ok
          ? 'El servicio recibió la notificación y el parser leyó '
              '${MoneyFormat.format(outcome!.transaction!.amountMinor)} en '
              '${outcome.transaction!.merchantRaw}. Si un banco no se registra, '
              'revisa que esté activado en "Apps detectadas" y mira '
              '"Notificaciones recibidas".'
          : result == null
              ? 'Android no entregó la notificación al servicio de escucha. '
                  'Desactiva y vuelve a activar Finaid en Acceso a notificaciones, '
                  'revisa los ajustes de batería de Samsung y repite la prueba.'
              : 'Motivo: ${ignoreReasonLabel(outcome?.ignoreReason)}'),
      actions: [
        if (!ok)
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              android.requestPermission();
            },
            child: const Text('Acceso a notificaciones'),
          ),
        FilledButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Listo')),
      ],
    ),
  );
}

/// Copia al portapapeles un reporte para depurar la captura.
Future<void> copyDiagnostics(BuildContext context, WidgetRef ref) async {
  final android = ref.read(androidSourceProvider);
  final messenger = ScaffoldMessenger.of(context);
  final report = DiagnosticsReport.build(
    appVersion: appVersionLabel,
    now: DateTime.now(),
    settings: ref.read(settingsProvider),
    device: await android?.deviceInfo(),
    status: await android?.status(),
    seen: await android?.seenPackages() ?? const [],
    recent: await ref.read(rawNotificationRepositoryProvider).recent(limit: 25),
  );
  await Clipboard.setData(ClipboardData(text: report));
  messenger.showSnackBar(const SnackBar(
    content: Text(
        'Diagnóstico copiado. Incluye el texto de tus notificaciones bancarias: revísalo antes de compartirlo.'),
  ));
}
