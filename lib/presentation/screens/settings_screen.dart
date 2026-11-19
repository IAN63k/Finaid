import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/app_info.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/money_format.dart';
import '../../domain/entities/bank.dart';
import '../../domain/entities/category.dart';
import '../../infrastructure/platform/android_notification_source.dart';
import '../widgets/common_widgets.dart';
import '../widgets/money_input_formatter.dart';
import 'capture_log_screen.dart';
import 'backup_screen.dart';
import 'capture_tools.dart';
import 'detected_apps_screen.dart';
import 'merchant_rules_screen.dart';
import 'security_settings.dart';
import 'simulate_notification_screen.dart';


class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final status = ref.watch(listenerStatusProvider).valueOrNull;
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
          const SectionTitle('Captura de notificaciones'),
          if (android == null)
            const Card(
              elevation: 0,
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Esta plataforma usa el atajo de ingesta'),
                subtitle: Text(
                    'Consulta docs/IOS.md para configurar la automatización de Atajos.'),
              ),
            )
          else
            _ServiceStatusCard(android: android, status: status),

          const SectionTitle('Fuentes que escucha'),
          Card(
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.radar),
                  title: const Text('Apps detectadas en este teléfono'),
                  subtitle: const Text(
                      'Si tu banco no aparece abajo o cambió de package, actívalo desde aquí.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const DetectedAppsScreen())),
                ),
                const Divider(height: 1),
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
                    value: bank.packages.any(settings.enabledPackages.contains),
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

          const SectionTitle('Avisos'),
          Card(
            elevation: 0,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Avisar cuando registre un movimiento'),
                  subtitle: const Text(
                      'Una notificación de Finaid con el monto, el comercio, la categoría y cómo va su presupuesto.'),
                  value: settings.notifyCaptures,
                  onChanged: (v) =>
                      ref.read(settingsProvider.notifier).setNotifyCaptures(v),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.savings_outlined),
                  title: const Text('Alertas de presupuesto'),
                  subtitle: const Text(
                      'Aviso destacado cuando un gasto te lleva al 80% o al 100% del presupuesto de su categoría, también con la app abierta.'),
                  value: settings.budgetAlerts,
                  onChanged: (v) =>
                      ref.read(settingsProvider.notifier).setBudgetAlerts(v),
                ),
              ],
            ),
          ),

          const SectionTitle('Ingresos y presupuestos'),
          Card(
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  leading: const CategoryAvatar(Categories.ingresos, radius: 16),
                  title: const Text('Ingreso mensual estimado'),
                  subtitle: const Text(
                      'Se usa en los consejos de ahorro cuando el banco no notifica tus ingresos.'),
                  trailing: Text(
                    settings.expectedMonthlyIncomeMinor == null
                        ? 'Sin definir'
                        : MoneyFormat.format(settings.expectedMonthlyIncomeMinor!),
                    style: TextStyle(
                      color: settings.expectedMonthlyIncomeMinor == null
                          ? scheme.outline
                          : scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () => _editExpectedIncome(
                      context, ref, settings.expectedMonthlyIncomeMinor),
                ),
                const Divider(height: 1),
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

          const SectionTitle('Seguridad'),
          const SecuritySettingsCard(),

          const SectionTitle('Tus datos'),
          Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('Respaldo y exportación'),
              subtitle: Text(settings.lastBackupAt == null
                  ? 'Aún no tienes respaldo · Exportar a Excel'
                  : 'Último respaldo: ${Dates.shortDate(settings.lastBackupAt!)}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BackupScreen())),
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
                  leading: const Icon(Icons.inbox_outlined),
                  title: const Text('Notificaciones recibidas'),
                  subtitle: const Text(
                      'Diagnóstico: qué llegó, qué se registró y qué se ignoró'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const CaptureLogScreen())),
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
            child: Text(appVersionLabel,
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

  Future<void> _editExpectedIncome(
      BuildContext context, WidgetRef ref, int? current) async {
    final result = await _askPesos(
      context,
      title: 'Ingreso mensual estimado',
      label: 'Lo que recibes al mes, en pesos',
      current: current,
    );
    if (result == null) return;
    await ref
        .read(settingsProvider.notifier)
        .setExpectedIncome(result <= 0 ? null : result);
  }

  Future<void> _editBudget(
      BuildContext context, WidgetRef ref, Category category, int? current) async {
    final result = await _askPesos(
      context,
      title: 'Presupuesto de ${category.name}',
      label: 'Límite mensual en pesos',
      current: current,
    );
    if (result == null) return;
    await ref
        .read(budgetsProvider.notifier)
        .setBudget(category.id, result <= 0 ? null : result);
  }

  /// Devuelve unidades menores, 0 para "quitar", o null si se canceló.
  Future<int?> _askPesos(BuildContext context,
      {required String title, required String label, int? current}) {
    final controller = TextEditingController(
        text: MoneyInputFormatter.fromPesos(current == null ? null : current ~/ 100));
    return showDialog<int?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: const [MoneyInputFormatter()],
          decoration: InputDecoration(prefixText: '\$ ', labelText: label),
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
              final pesos = MoneyInputFormatter.parse(controller.text) ?? 0;
              Navigator.pop(ctx, pesos * 100);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

class _ServiceStatusCard extends ConsumerWidget {
  const _ServiceStatusCard({required this.android, required this.status});

  final AndroidNotificationSource android;
  final ListenerStatus? status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final s = status;
    final ok = AppTheme.income(context);
    final warn = AppTheme.warning(context);

    Widget row({
      required bool? good,
      required String title,
      required String subtitle,
      Widget? action,
    }) {
      return ListTile(
        leading: Icon(
          good == null
              ? Icons.hourglass_empty
              : good
                  ? Icons.check_circle
                  : Icons.error_outline,
          color: good == null ? scheme.outline : (good ? ok : warn),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: action,
      );
    }

    Future<void> refresh() async {
      ref.invalidate(listenerStatusProvider);
      ref.invalidate(permissionStatusProvider);
    }

    return Card(
      elevation: 0,
      child: Column(
        children: [
          row(
            good: s?.permissionGranted,
            title: 'Acceso a notificaciones',
            subtitle: s?.permissionGranted == true
                ? 'Concedido'
                : 'Sin él Finaid no ve ninguna notificación',
            action: s?.permissionGranted == true
                ? null
                : FilledButton.tonal(
                    onPressed: () => android.requestPermission(),
                    child: const Text('Activar'),
                  ),
          ),
          row(
            good: s?.listenerConnected,
            title: 'Servicio de escucha',
            subtitle: s?.listenerConnected == true
                ? 'Conectado y recibiendo notificaciones'
                : 'Desconectado: el sistema lo suspendió o aún no lo enlazó',
            action: s?.listenerConnected == true
                ? null
                : TextButton(
                    onPressed: () async {
                      await android.requestRebind();
                      await Future<void>.delayed(const Duration(seconds: 1));
                      await refresh();
                    },
                    child: const Text('Reconectar'),
                  ),
          ),
          row(
            good: s?.batteryUnrestricted,
            title: 'Batería sin restricciones',
            subtitle: s?.batteryUnrestricted == true
                ? 'Android no suspenderá el servicio en segundo plano'
                : 'Recomendado: evita que el sistema "duerma" a Finaid',
            action: s?.batteryUnrestricted == true
                ? null
                : TextButton(
                    onPressed: () => android.openBatterySettings(),
                    child: const Text('Permitir'),
                  ),
          ),
          row(
            good: s?.canPostNotifications,
            title: 'Avisos de Finaid',
            subtitle: s?.canPostNotifications == true
                ? 'Puede avisarte cuando registre un movimiento'
                : 'Permite las notificaciones de Finaid para recibir avisos',
            action: s?.canPostNotifications == true
                ? null
                : TextButton(
                    onPressed: () async {
                      await android.requestPostNotificationPermission();
                      await Future<void>.delayed(const Duration(seconds: 2));
                      await refresh();
                    },
                    child: const Text('Permitir'),
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final found = await android.scanActiveNotifications();
                      final ingested =
                          await ref.read(ingestionServiceProvider).drainAll();
                      await refresh();
                      if (!context.mounted) return;
                      final msg = found < 0
                          ? 'El servicio no está conectado. Toca "Reconectar" o revisa el permiso.'
                          : ingested == 0
                              ? 'No hay notificaciones nuevas en la bandeja'
                              : '$ingested movimiento${ingested == 1 ? '' : 's'} nuevo${ingested == 1 ? '' : 's'}';
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(msg)));
                    },
                    icon: const Icon(Icons.manage_search),
                    label: const Text('Buscar en la bandeja'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Volver a comprobar',
                  onPressed: refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => runCaptureSelfTest(context, ref),
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('Probar captura'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => copyDiagnostics(context, ref),
                    icon: const Icon(Icons.content_copy),
                    label: const Text('Copiar diagnóstico'),
                  ),
                ),
              ],
            ),
          ),
          ExpansionTile(
            leading: const Icon(Icons.phone_android),
            title: const Text('Si tienes Samsung (One UI)'),
            subtitle: const Text(
                'One UI suspende las apps que no usas y desconecta el servicio'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text(
                '1. Ajustes → Batería → Límites de uso en segundo plano → '
                '"Apps que nunca se suspenden" → agrega Finaid.\n'
                '2. En la misma pantalla desactiva "Suspender apps que no usas" (o quita a Finaid de las listas de suspensión).\n'
                '3. Ajustes → Aplicaciones → Finaid → Batería → "Sin restricciones".\n'
                '4. Ajustes → Aplicaciones → Finaid → Notificaciones → permitir.\n\n'
                'Aunque el servicio se desconecte un rato, al abrir Finaid se revisan las notificaciones que sigan en la bandeja.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant, height: 1.45),
              ),
            ],
          ),
          if (Platform.isAndroid)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'Finaid solo lee las apps activadas abajo. Nunca ve tus claves ni se conecta a tu banco.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}
