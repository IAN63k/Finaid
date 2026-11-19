import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../core/utils/date_utils.dart';
import '../../domain/entities/bank.dart';
import '../../infrastructure/platform/android_notification_source.dart';
import '../widgets/common_widgets.dart';

/// Apps que han emitido notificaciones en este teléfono, para activar la
/// escucha con el package real (los bancos cambian de package con frecuencia).
/// Las que parecen bancarias se activan solas, salvo que el usuario las apague.
class DetectedAppsScreen extends ConsumerWidget {
  const DetectedAppsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seen = ref.watch(seenPackagesProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Apps detectadas'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(seenPackagesProvider),
          ),
        ],
      ),
      body: seen.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'No se pudo leer la lista',
          message: '$e',
        ),
        data: (apps) {
          if (apps.isEmpty) {
            return const EmptyState(
              icon: Icons.apps,
              title: 'Todavía no hay apps detectadas',
              message:
                  'El servicio anota qué apps notifican (solo el nombre, nunca el contenido). Cuando llegue una notificación de tu banco aparecerá aquí.',
            );
          }
          final banks = apps.where((a) => a.looksLikeBank).toList();
          final others = apps.where((a) => !a.looksLikeBank).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(
                'Las apps que parecen bancarias se escuchan automáticamente. '
                'Solo se guarda el nombre de cada app y cuántas veces notificó; '
                'el contenido solo se lee de las apps activadas.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              if (banks.isNotEmpty) ...[
                const SectionTitle('Bancos y billeteras'),
                _AppsCard(apps: banks),
              ],
              if (others.isNotEmpty) ...[
                const SectionTitle('Otras apps'),
                _AppsCard(apps: others),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AppsCard extends ConsumerWidget {
  const _AppsCard({required this.apps});

  final List<SeenPackage> apps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(settingsProvider).enabledPackages;
    final disabled = ref.watch(settingsProvider).disabledPackages;
    return Card(
      elevation: 0,
      child: Column(
        children: [
          for (final app in apps)
            SwitchListTile(
              secondary: CircleAvatar(
                backgroundColor: _color(app.package).withAlpha(50),
                child: Text(
                  app.label.isEmpty ? '?' : app.label[0].toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(app.label),
              subtitle: Text(
                '${app.package}\n${app.count} notificación${app.count == 1 ? '' : 'es'} · última ${Dates.dayLabel(app.lastSeen).toLowerCase()} ${Dates.timeLabel(app.lastSeen)}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              isThreeLine: true,
              value: enabled.contains(app.package) ||
                  (app.looksLikeBank && !disabled.contains(app.package)),
              onChanged: (v) => ref
                  .read(settingsProvider.notifier)
                  .setPackageEnabled(app.package, v),
            ),
        ],
      ),
    );
  }

  Color _color(String package) {
    final bank = KnownBanks.byPackage(package);
    return bank == null ? const Color(0xFF607D8B) : Color(bank.color);
  }
}
