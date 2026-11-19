import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/money_format.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/recurring/recurring.dart';
import '../widgets/common_widgets.dart';
import '../widgets/money_input_formatter.dart';

/// "Hoy", "Mañana", "En 5 días", "Venció hace 2 días".
String dueLabel(int days) {
  if (days < 0) return 'Venció hace ${-days} día${days == -1 ? '' : 's'}';
  if (days == 0) return 'Hoy';
  if (days == 1) return 'Mañana';
  return 'En $days días';
}

Color dueColor(BuildContext context, int days) {
  if (days < 0) return Theme.of(context).colorScheme.error;
  if (days <= 2) return AppTheme.warning(context);
  return Theme.of(context).colorScheme.onSurfaceVariant;
}

/// Pagos que se repiten cada mes: detectados en el historial y agregados a mano.
class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = ref.watch(recurringPaymentsProvider);
    final scheme = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pagos recurrentes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showRecurringEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Agregar pago'),
      ),
      body: payments.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
            icon: Icons.error_outline, title: 'No se pudo cargar', message: '$e'),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.event_repeat,
              title: 'Aún no hay pagos recurrentes',
              message:
                  'Finaid los detecta cuando un mismo cobro se repite cada mes (suscripciones, servicios). '
                  'También puedes agregar a mano los que no llegan por notificación: arriendo, administración, cuotas.',
            );
          }
          final now = DateTime.now();
          final next30 = list.where((p) {
            final d = p.daysUntil(now);
            return d >= 0 && d <= 30;
          });
          final total = next30.fold<int>(0, (a, p) => a + p.amountMinor);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Card(
                elevation: 0,
                color: scheme.primaryContainer,
                child: ListTile(
                  leading: Icon(Icons.event_repeat, color: scheme.onPrimaryContainer),
                  title: Text('~${MoneyFormat.format(total)} en los próximos 30 días',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: scheme.onPrimaryContainer)),
                  subtitle: Text(
                    settings.remindersEnabled
                        ? '${next30.length} pago${next30.length == 1 ? '' : 's'} · te avisamos ${settings.reminderDaysBefore} día${settings.reminderDaysBefore == 1 ? '' : 's'} antes'
                        : '${next30.length} pago${next30.length == 1 ? '' : 's'} · recordatorios desactivados en Ajustes',
                    style: TextStyle(color: scheme.onPrimaryContainer),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                child: Column(
                  children: [
                    for (final p in list)
                      RecurringTile(
                        payment: p,
                        now: now,
                        onTap: () => _showActions(context, ref, p),
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

  Future<void> _showActions(
      BuildContext context, WidgetRef ref, RecurringPayment p) async {
    final service = ref.read(recurringServiceProvider);
    final messenger = ScaffoldMessenger.of(context);

    void refresh() {
      ref.invalidate(recurringPaymentsProvider);
      ref.read(reminderSyncProvider).sync();
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: CategoryAvatar(Categories.byId(p.categoryId)),
              title: Text(p.name,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                  '${p.isManual ? '' : '~'}${MoneyFormat.format(p.amountMinor, currency: p.currency)} · '
                  'próximo ${Dates.dayLabel(p.nextDueAt).toLowerCase()}'),
            ),
            const Divider(height: 1),
            SwitchListTile(
              secondary: const Icon(Icons.notifications_outlined),
              title: const Text('Recordarme antes'),
              value: p.remind,
              onChanged: (v) async {
                Navigator.pop(ctx);
                await service.setRemind(p, v);
                refresh();
              },
            ),
            if (p.isManual) ...[
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Registrar el pago de este mes'),
                subtitle: const Text('Crea el gasto y pasa la fecha al mes siguiente'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final item = await service.manualById(p.id);
                  if (item == null) return;
                  await ref.read(editUseCasesProvider).addManual(
                        amountMinor: item.amountMinor,
                        kind: TransactionKind.billPayment,
                        description: item.name,
                        categoryId: item.categoryId,
                        occurredAt: DateTime.now(),
                      );
                  await service.markManualPaid(item, p.nextDueAt);
                  await ref.read(transactionsProvider.notifier).reload();
                  refresh();
                  messenger.showSnackBar(SnackBar(
                      content: Text('Pago de ${item.name} registrado.')));
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Editar'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final item = await service.manualById(p.id);
                  if (item != null && context.mounted) {
                    await showRecurringEditor(context, existing: item);
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline,
                    color: Theme.of(ctx).colorScheme.error),
                title: const Text('Eliminar'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await service.deleteManual(p.id);
                  refresh();
                  messenger.showSnackBar(
                      SnackBar(content: Text('${p.name} eliminado.')));
                },
              ),
            ] else
              ListTile(
                leading: const Icon(Icons.block),
                title: const Text('No es un pago recurrente'),
                subtitle: Text(
                    'Detectado por ${p.occurrences} cobros parecidos cada mes'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await service.dismiss(p);
                  refresh();
                  messenger.showSnackBar(SnackBar(
                    content: Text('${p.name} ya no se mostrará.'),
                    action: SnackBarAction(
                      label: 'Deshacer',
                      onPressed: () async {
                        await service.restore(p);
                        refresh();
                      },
                    ),
                  ));
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class RecurringTile extends StatelessWidget {
  const RecurringTile({
    super.key,
    required this.payment,
    required this.now,
    this.onTap,
  });

  final RecurringPayment payment;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = payment;
    final days = p.daysUntil(now);
    final color = dueColor(context, days);
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      leading: CategoryAvatar(Categories.byId(p.categoryId)),
      title: Row(
        children: [
          Expanded(
            child: Text(p.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          if (!p.remind)
            Icon(Icons.notifications_off_outlined, size: 16, color: scheme.outline),
        ],
      ),
      subtitle: Text(
        '${Dates.dayLabel(p.nextDueAt, now: now)} · '
        '${p.isManual ? 'Agregado por ti' : 'Detectado (${p.occurrences} cobros)'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${p.isManual ? '' : '~'}${MoneyFormat.format(p.amountMinor, currency: p.currency)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(dueLabel(days),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Agregar o editar un pago mensual manual.
Future<void> showRecurringEditor(BuildContext context, {ManualRecurring? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _RecurringEditor(existing: existing),
  );
}

class _RecurringEditor extends ConsumerStatefulWidget {
  const _RecurringEditor({this.existing});

  final ManualRecurring? existing;

  @override
  ConsumerState<_RecurringEditor> createState() => _RecurringEditorState();
}

class _RecurringEditorState extends ConsumerState<_RecurringEditor> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _amount = TextEditingController(
      text: MoneyInputFormatter.fromPesos(
          widget.existing == null ? null : widget.existing!.amountMinor ~/ 100));
  late int _day = widget.existing?.dayOfMonth ?? DateTime.now().day;
  late String _categoryId = widget.existing?.categoryId ?? Categories.hogar.id;
  late bool _remind = widget.existing?.remind ?? true;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final pesos = MoneyInputFormatter.parse(_amount.text);
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Ponle un nombre (arriendo, administración, cuota…).');
      return;
    }
    if (pesos == null || pesos <= 0) {
      setState(() => _error = 'Escribe el monto.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    await ref.read(recurringServiceProvider).saveManual(
          id: widget.existing?.id,
          name: name,
          amountMinor: pesos * 100,
          categoryId: _categoryId,
          dayOfMonth: _day,
          remind: _remind,
        );
    ref.invalidate(recurringPaymentsProvider);
    await ref.read(reminderSyncProvider).sync();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Text(widget.existing == null ? 'Agregar pago mensual' : 'Editar pago mensual',
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            'Para pagos que no llegan por notificación o que haces tú: arriendo, administración, cuotas, colegio.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: widget.existing == null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: const [MoneyInputFormatter()],
            decoration: const InputDecoration(
                prefixText: '\$ ', labelText: 'Monto mensual en pesos'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _day,
            decoration: const InputDecoration(labelText: 'Día del mes en que se paga'),
            items: [
              for (var d = 1; d <= 31; d++)
                DropdownMenuItem(
                    value: d,
                    child: Text(d >= 29 ? 'Día $d (o el último del mes)' : 'Día $d')),
            ],
            onChanged: (v) => setState(() => _day = v ?? _day),
          ),
          const SizedBox(height: 16),
          Text('Categoría', style: text.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in Categories.expenses)
                ChoiceChip(
                  avatar: Text(c.emoji),
                  label: Text(c.name),
                  selected: _categoryId == c.id,
                  onSelected: (_) => setState(() => _categoryId = c.id),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _remind,
            onChanged: (v) => setState(() => _remind = v),
            title: const Text('Recordarme antes'),
            subtitle: const Text('Y también el mismo día, para registrar el pago.'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: TextStyle(color: scheme.error)),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
            label: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
