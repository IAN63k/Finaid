import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/device/device_guide.dart';
import '../../infrastructure/platform/android_notification_source.dart';

/// Guía de batería y segundo plano según el fabricante del teléfono.
class PhoneGuideTile extends ConsumerWidget {
  const PhoneGuideTile({super.key, required this.android});

  final AndroidNotificationSource android;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(deviceInfoProvider).valueOrNull;
    final guide = DeviceGuide.forDevice(
      manufacturer: device?.manufacturer ?? '',
      sdk: device?.sdk ?? 0,
    );
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.45);

    return ExpansionTile(
      leading: const Icon(Icons.phone_android),
      title: Text('Configura tu ${guide.displayName}'),
      subtitle: Text(device == null
          ? 'Para que el sistema no detenga la captura'
          : 'Para que ${device.manufacturer} no detenga la captura en segundo plano'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < guide.steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              i == guide.steps.length - 1 ? guide.steps[i] : '${i + 1}. ${guide.steps[i]}',
              style: muted,
            ),
          ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (guide.offerAutostart)
              FilledButton.tonal(
                onPressed: () async {
                  final opened = await android.openAutostartSettings();
                  if (!opened && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'Tu teléfono no tiene esa pantalla; se abrió la información de Finaid.')));
                  }
                },
                child: const Text('Inicio automático'),
              ),
            OutlinedButton(
              onPressed: () => android.openBatterySettings(),
              child: const Text('Batería'),
            ),
            OutlinedButton(
              onPressed: () => android.openAppDetails(),
              child: const Text('Información de la app'),
            ),
          ],
        ),
        if (guide.showRestrictedSettingsTip) ...[
          const SizedBox(height: 16),
          Text('¿El acceso a notificaciones aparece gris o dice "Ajuste restringido"?',
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          for (var i = 0; i < DeviceGuide.restrictedSettingsSteps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('${i + 1}. ${DeviceGuide.restrictedSettingsSteps[i]}', style: muted),
            ),
        ],
      ],
    );
  }
}

/// Explica cómo habilitar el acceso a notificaciones cuando Android lo marca
/// como "Ajuste restringido" (apps instaladas desde un archivo, Android 13+).
Future<void> showRestrictedSettingsHelp(
    BuildContext context, AndroidNotificationSource android) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.lock_outline),
      title: const Text('Si el interruptor sale gris'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
              'Android protege el acceso a notificaciones de las apps instaladas desde un archivo. Para habilitarlo:'),
          const SizedBox(height: 12),
          for (var i = 0; i < DeviceGuide.restrictedSettingsSteps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('${i + 1}. ${DeviceGuide.restrictedSettingsSteps[i]}'),
            ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        FilledButton(
          onPressed: () {
            Navigator.pop(ctx);
            android.openAppDetails();
          },
          child: const Text('Información de la app'),
        ),
      ],
    ),
  );
}
