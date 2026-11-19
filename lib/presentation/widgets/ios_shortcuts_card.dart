import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../infrastructure/platform/local_notifier.dart';

/// Proveedor del estado del permiso de avisos (iOS).
final _iosNotificationsAllowedProvider = FutureProvider.autoDispose<bool>((ref) async {
  final notifier = ref.watch(localNotifierProvider);
  return notifier?.hasPostNotificationPermission() ?? Future.value(false);
});

/// Recetas de Atajos para capturar movimientos en iPhone. iOS no deja leer las
/// notificaciones de otras apps, así que se usan automatizaciones que abren
/// `finaid://ingest` con el texto del SMS del banco o del pago con Apple Pay.
class IosShortcutsCard extends ConsumerWidget {
  const IosShortcutsCard({super.key});

  static const String smsLink = 'finaid://ingest?app=ios.sms&text=';
  static const String walletLink = 'finaid://ingest?app=ios.wallet&text=';
  static const String shareLink = 'finaid://ingest?app=ios.share&text=';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final allowed = ref.watch(_iosNotificationsAllowedProvider).valueOrNull;
    final notifier = ref.watch(localNotifierProvider);
    final bridge = notifier is IosPlatformBridge ? notifier : null;
    final muted = text.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.45);

    Widget recipe({
      required IconData icon,
      required String title,
      required String subtitle,
      required List<String> steps,
      required String link,
    }) {
      return ExpansionTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('${i + 1}. ${steps[i]}', style: muted),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: link));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Copiado: $link')));
                }
              },
              icon: const Icon(Icons.content_copy, size: 18),
              label: const Text('Copiar el enlace para "Abrir URL"'),
            ),
          ),
        ],
      );
    }

    return Card(
      elevation: 0,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('En iPhone la captura es con Atajos'),
            subtitle: const Text(
                'iOS no deja que una app lea las notificaciones de otra. Con una automatización de Atajos, '
                'los SMS de tu banco y tus pagos con Apple Pay llegan solos a Finaid.'),
          ),
          ListTile(
            leading: Icon(
              allowed == true ? Icons.check_circle : Icons.notifications_off_outlined,
              color: allowed == true ? AppTheme.income(context) : AppTheme.warning(context),
            ),
            title: const Text('Avisos de Finaid'),
            subtitle: Text(allowed == true
                ? 'Activos: alertas de presupuesto y recordatorios de pagos'
                : 'Permítelos para recibir alertas de presupuesto y recordatorios'),
            trailing: allowed == true || notifier == null
                ? null
                : TextButton(
                    onPressed: () async {
                      await notifier.requestPostNotificationPermission();
                      ref.invalidate(_iosNotificationsAllowedProvider);
                    },
                    child: const Text('Permitir'),
                  ),
          ),
          const Divider(height: 1),
          recipe(
            icon: Icons.sms_outlined,
            title: 'SMS de tu banco',
            subtitle: 'Bancolombia, Davivienda, BBVA… avisan por mensaje de texto',
            link: smsLink,
            steps: const [
              'Abre Atajos → Automatización → "+" → Mensaje.',
              'En "Remitente" elige el número o nombre de tu banco (o usa "El mensaje contiene" con "compra").',
              'Elige "Ejecutar inmediatamente" y toca Siguiente.',
              'Agrega la acción "Codificar URL" con la variable "Mensaje" (o "Contenido").',
              'Agrega "Abrir URL" y escribe el enlace copiado seguido de la variable "Texto codificado en URL".',
            ],
          ),
          recipe(
            icon: Icons.contactless_outlined,
            title: 'Pagos con Apple Pay',
            subtitle: 'Automatización "Transacción" de Wallet',
            link: walletLink,
            steps: const [
              'Atajos → Automatización → "+" → Transacción.',
              'Elige tus tarjetas y "Ejecutar inmediatamente".',
              'Agrega la acción "Texto" con: Compra por [Monto] en [Comercio].',
              'Agrega "Codificar URL" con ese texto.',
              'Agrega "Abrir URL" con el enlace copiado seguido del "Texto codificado en URL".',
            ],
          ),
          recipe(
            icon: Icons.ios_share,
            title: 'Desde cualquier app (compartir)',
            subtitle: 'Para notificaciones o textos que copies',
            link: shareLink,
            steps: const [
              'Atajos → "+" (nuevo atajo) → en Detalles activa "Mostrar en hoja de compartir" y acepta Texto.',
              'Agrega "Codificar URL" con la "Entrada del atajo".',
              'Agrega "Abrir URL" con el enlace copiado seguido del "Texto codificado en URL".',
              'Luego, al compartir un texto, elige ese atajo y el movimiento llega a Finaid.',
            ],
          ),
          if (bridge != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => bridge.openShortcuts(),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Abrir Atajos'),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'Cada automatización abre Finaid un instante para registrar el movimiento. '
              'Para probar sin esperar una compra usa "Simular notificación".',
              style: muted,
            ),
          ),
        ],
      ),
    );
  }
}
