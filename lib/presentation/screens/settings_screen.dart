import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money_format.dart';
import '../../domain/entities/bank.dart';
import '../../domain/entities/category.dart';
import '../widgets/common_widgets.dart';
import 'merchant_rules_screen.dart';
import 'simulate_notification_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final permission = ref.watch(permissionStatusProvider);
    final budgets = ref.watch(budgetsProvider).valueOrNull ?? const {};
    final rules = ref.watch(merchantRulesProvider).valueOrNull ?? const [];
    final android = ref.watch(androidSourceProvider);
    final scheme = Theme.of(context).colorScheme;

    final customPackages = settings.enabledPackages
        .where((p) => !KnownBanks.defaultPackages.contains(p))
        .toList()
      ..sort();

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          const SectionTitle('Lectura de notificaciones'),
          Card(
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    permission.valueOrNull == true
                        ? Icons.check_circle
                        : Icons.error_outline,
                    color: permission.valueOrNull == true
                        ? AppTheme.income(context)
                        : AppTheme.warning(context),
                  ),
                  title: Text(
                    Platform.isAndroid
                        ? (permission.valueOrNull == true
                            ? 'Acceso a notificaciones activo'
                            : 'Acceso a notificaciones desactivado')
                        : 'Esta plataforma usa el atajo de ingesta',
                  ),
                  subtitle: Text(Platform.isAndroid
                      ? 'Finaid solo lee las apps que elijas abajo. Nunca ve tus claves ni se conecta a tu banco.'
                      : 'Consulta docs/IOS.md para configurar la automatización de Atajos.'),
                ),
                if (android != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        FilledButton.tonal(
                          onPressed: () async {
                            await android.requestPermission();
                          },
                          child: const Text('Abrir ajustes del sistema'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () async {
                            await android.requestRebind();
                            ref.invalidate(permissionStatusProvider);
                          },
                          child: const Text('Volver a comprobar'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const SectionTitle('Fuentes que escucha'),
          Card(
            elevation: 0,
            child: Column(
              children: [
                for (final bank in KnownBanks.all)
                  SwitchListTile(
                    secondary: CircleAvatar(
                      backgroundColor: Color(bank.color).withAlpha(50),
                      child: Text(bank.name[0],
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    title: Text(bank.name),
                    subtitle: Text(bank.packages.first,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    value: bank.packages
                        .any(settings.enabledPackages.contains),
                    onChanged: (v) {
                      final notifier = ref.read(settingsProvider.notifier);
                      for (final p in bank.packages) {
                        notifier.setPackageEnabled(p, v);
                      }
                    },
                  ),
                SwitchListTile(
                  secondary: const CircleAvatar(child: Icon(Icons.sms_outlined)),
                  title: const Text('Mensajes SMS'),
                  subtitle: const Text(
                      'Los bancos también avisan por SMS. Se deduplican con la notificación de la app.'),
                  value: KnownBanks.smsPackages
                      .any(settings.enabledPackages.contains),
                  onChanged: (v) {
                    final notifier = ref.read(settingsProvider.notifier);
                    for (final p in KnownBanks.smsPackages) {
                      notifier.setPackageEnabled(p, v);
                    }
                  },
                ),
                for (final p in customPackages)
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.apps)),
                    title: Text(p),
                    subtitle: const Text('Package personalizado'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => ref
                          .read(settingsProvider.notifier)
                          .setPackageEnabled(p, false),
                    ),
                  ),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('Agregar otra app por package'),
                  subtitle: const Text('Ej.: com.banco.app'),
                  onTap: () => _addPackage(context, ref),
                ),
              ],
            ),
          ),

          const SectionTitle('Presupuestos mensuales'),
          Card(
            elevation: 0,
            child: Column(
              children: [
                for (final c in Categories.expenses)
                  ListTile(
                    leading: CategoryAvatar(c, radius: 16),
                    title: Text(c.name),
                    trailing: Text(
                      budgets.containsKey(c.id)
                          ? MoneyFormat.format(budgets[c.id]!)
                          : 'Sin límite',
                      style: TextStyle(
                        color: budgets.containsKey(c.id)
                            ? scheme.onSurface
                            : scheme.outline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () => _editBudget(context, ref, c, budgets[c.id]),
                  ),
              ],
            ),
          ),

          const SectionTitle('Reglas y herramientas'),
          Card(
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.rule),
                  title: const Text('Reglas por comercio'),
                  subtitle: Text(rules.isEmpty
                      ? 'Se crean al elegir "Aplicar siempre" en un movimiento'
                      : '${rules.length} regla${rules.length == 1 ? '' : 's'}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const MerchantRulesScreen())),
                ),
                ListTile(
                  leading: const Icon(Icons.science_outlined),
                  title: const Text('Simular notificación'),
                  subtitle: const Text(
                      'Pega el texto de un mensaje bancario y mira cómo se interpreta'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const SimulateNotificationScreen())),
                ),
                ListTile(
                  leading: const Icon(Icons.sync),
                  title: const Text('Procesar notificaciones pendientes'),
                  onTap: () async {
                    final n =
                        await ref.read(ingestionServiceProvider).drainAll();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('$n movimiento${n == 1 ? '' : 's'} nuevo${n == 1 ? '' : 's'}')));
                  },
                ),
              ],
            ),
          ),

          const SectionTitle('Privacidad'),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Finaid no pide usuario ni contraseña de ningún banco y no tiene servidor: '
                'las notificaciones se leen y se guardan solo en este teléfono. '
                'Puedes revocar el acceso en cualquier momento desde los ajustes de Android.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('Finaid 0.1.1',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: scheme.outline)),
          ),
        ],
      ),
    );
  }

  Future<void> _addPackage(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar app'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
              labelText: 'Package de Android', hintText: 'com.banco.app'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Agregar')),
        ],
      ),
    );
    if (value == null || value.isEmpty) return;
    await ref.read(settingsProvider.notifier).setPackageEnabled(value, true);
  }

  Future<void> _editBudget(
      BuildContext context, WidgetRef ref, Category category, int? current) async {
    final controller = TextEditingController(
        text: current == null ? '' : (current ~/ 100).toString());
    final result = await showDialog<int?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Presupuesto de ${category.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
              prefixText: '\$ ', labelText: 'Límite mensual en pesos'),
        ),
        actions: [
          if (current != null)
            TextButton(
                onPressed: () => Navigator.pop(ctx, 0),
                child: const Text('Quitar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final pesos = int.tryParse(controller.text.trim()) ?? 0;
              Navigator.pop(ctx, pesos * 100);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (result == null) return;
    await ref
        .read(budgetsProvider.notifier)
        .setBudget(category.id, result <= 0 ? null : result);
  }
}
