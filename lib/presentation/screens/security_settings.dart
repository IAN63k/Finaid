import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/app_lock.dart';
import '../../application/providers.dart';
import '../../infrastructure/platform/device_auth.dart';

/// Ajustes → Seguridad: bloqueo con huella, rostro o PIN.
class SecuritySettingsCard extends ConsumerWidget {
  const SecuritySettingsCard({super.key});

  static const Map<int, String> timeouts = {
    0: 'Cada vez que salgas de la app',
    60: 'Después de 1 minuto fuera',
    300: 'Después de 5 minutos fuera',
  };

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool enable) async {
    final messenger = ScaffoldMessenger.of(context);
    final auth = ref.read(deviceAuthProvider);
    final status = await auth.status();
    if (!status.available) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.lock_outline),
          title: const Text('Primero protege tu teléfono'),
          content: const Text(
              'Para bloquear Finaid, tu teléfono necesita un bloqueo de pantalla '
              '(PIN, patrón o contraseña). Configúralo en Ajustes de Android → '
              'Pantalla de bloqueo, y registra tu huella o rostro si quieres usarlos.'),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
          ],
        ),
      );
      return;
    }

    // Confirmar con la huella antes de activar (comprueba que funciona) y antes
    // de desactivar (que otra persona no pueda quitarlo).
    final outcome = await auth.authenticate(
      title: enable ? 'Activar bloqueo de Finaid' : 'Desactivar bloqueo de Finaid',
      subtitle: 'Confirma que eres tú',
    );
    if (outcome != AuthOutcome.success) {
      messenger.showSnackBar(SnackBar(
          content: Text(outcome == AuthOutcome.lockout
              ? 'Demasiados intentos. Espera un momento.'
              : 'No se confirmó; el bloqueo no cambió.')));
      return;
    }
    await ref.read(settingsProvider.notifier).setLockEnabled(enable);
    // Los recordatorios programados ocultan montos si hay bloqueo.
    await ref.read(reminderSyncProvider).sync();
    messenger.showSnackBar(SnackBar(
        content: Text(enable
            ? (status.biometric
                ? 'Listo: Finaid pedirá tu huella o rostro.'
                : 'Listo: Finaid pedirá el PIN del teléfono. Registra tu huella en Android para usarla.')
            : 'Bloqueo desactivado.')));
  }

  Future<void> _chooseTimeout(BuildContext context, WidgetRef ref, int current) async {
    final chosen = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Pedir la huella de nuevo'),
        children: [
          for (final e in timeouts.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, e.key),
              child: Row(
                children: [
                  Icon(e.key == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked),
                  const SizedBox(width: 12),
                  Expanded(child: Text(e.value)),
                ],
              ),
            ),
        ],
      ),
    );
    if (chosen == null) return;
    await ref.read(settingsProvider.notifier).setLockTimeout(chosen);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return Card(
      elevation: 0,
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: const Text('Bloquear con huella o PIN'),
            subtitle: const Text(
                'Pide tu huella, rostro o el PIN del teléfono al abrir Finaid. '
                'Los avisos ocultan los montos en la pantalla de bloqueo del teléfono.'),
            value: settings.lockEnabled,
            onChanged: (v) => _toggle(context, ref, v),
          ),
          if (settings.lockEnabled)
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('Pedir de nuevo'),
              subtitle: Text(timeouts[settings.lockTimeoutSeconds] ??
                  'Después de ${settings.lockTimeoutSeconds} s fuera'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _chooseTimeout(context, ref, settings.lockTimeoutSeconds),
            ),
        ],
      ),
    );
  }
}
