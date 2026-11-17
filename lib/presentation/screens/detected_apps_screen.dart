import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../core/utils/date_utils.dart';
import '../../domain/entities/bank.dart';
import '../widgets/common_widgets.dart';

/// Apps que han emitido notificaciones en este teléfono, para activar la
/// escucha con el package real (los bancos cambian de package con frecuencia).
class DetectedAppsScreen extends ConsumerWidget {
  const DetectedAppsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seen = ref.watch(seenPackagesProvider);
    final settings = ref.watch(settingsProvider);
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
                  'El servicio anota qué apps notifican (solo el nombre, nunca el contenido). Cuando llegue una notificación de tu banco aparecerá aquí para activarla.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(
                'Activa las apps de tus bancos y billeteras. Solo se guarda el nombre de la app y cuántas veces notificó; el contenido solo se lee de las apps activadas.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Card(
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
                        value: settings.enabledPackages.contains(app.package),
                        onChanged: (v) => ref
                            .read(settingsProvider.notifier)
                            .setPackageEnabled(app.package, v),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _color(String package) {
    final bank = KnownBanks.byPackage(package);
    return bank == null ? const Color(0xFF607D8B) : Color(bank.color);
  }
}
