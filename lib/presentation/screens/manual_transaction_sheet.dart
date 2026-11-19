import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../core/utils/date_utils.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/transaction.dart';
import '../widgets/common_widgets.dart';
import '../widgets/money_input_formatter.dart';

Future<void> showManualTransactionSheet(BuildContext context,
    {bool income = false}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => ManualTransactionSheet(initialIncome: income),
  );
}

/// Registro a mano de un ingreso o un gasto (efectivo, pagos sin
/// notificación, ingresos mensuales…).
class ManualTransactionSheet extends ConsumerStatefulWidget {
  const ManualTransactionSheet({super.key, this.initialIncome = false});

  final bool initialIncome;

  @override
  ConsumerState<ManualTransactionSheet> createState() =>
      _ManualTransactionSheetState();
}

class _ManualTransactionSheetState extends ConsumerState<ManualTransactionSheet> {
  final _amount = TextEditingController();
  final _description = TextEditingController();
  late bool _income = widget.initialIncome;
  late String _categoryId =
      widget.initialIncome ? Categories.ingresos.id : Categories.otros.id;
  DateTime _when = DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime(DateTime.now().year - 3),
      lastDate: DateTime.now(),
      locale: const Locale('es'),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    setState(() {
      _when = DateTime(date.year, date.month, date.day, time?.hour ?? _when.hour,
          time?.minute ?? _when.minute);
    });
  }

  Future<void> _save() async {
    final pesos = MoneyInputFormatter.parse(_amount.text);
    final description = _description.text.trim();
    if (pesos == null || pesos <= 0) {
      setState(() => _error = 'Escribe un monto mayor que cero.');
      return;
    }
    if (description.isEmpty) {
      setState(() => _error = 'Escribe una descripción (comercio, concepto…).');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    await ref.read(editUseCasesProvider).addManual(
          amountMinor: pesos * 100,
          kind: _income ? TransactionKind.deposit : TransactionKind.purchase,
          description: description,
          categoryId: _income ? Categories.ingresos.id : _categoryId,
          occurredAt: _when,
        );
    await ref.read(transactionsProvider.notifier).reload();
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
          Text('Registrar a mano',
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            'Para ingresos o gastos que no llegan por notificación: efectivo, nómina, arriendos…',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                  value: false,
                  label: Text('Gasto'),
                  icon: Icon(Icons.arrow_upward, size: 16)),
              ButtonSegment(
                  value: true,
                  label: Text('Ingreso'),
                  icon: Icon(Icons.arrow_downward, size: 16)),
            ],
            selected: {_income},
            onSelectionChanged: (s) => setState(() {
              _income = s.first;
              _categoryId =
                  _income ? Categories.ingresos.id : Categories.otros.id;
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: const [MoneyInputFormatter()],
            decoration: const InputDecoration(
                prefixText: '\$ ', labelText: 'Monto en pesos'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: _income ? 'Concepto' : 'Comercio o concepto',
              hintText: _income ? 'Nómina, arriendo, venta…' : 'Tienda, taxi, mercado…',
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(Dates.shortDate(_when)),
            subtitle: const Text('Fecha y hora'),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: _pickDate,
          ),
          if (!_income) ...[
            const SizedBox(height: 8),
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
          ] else ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const CategoryAvatar(Categories.ingresos, radius: 14),
                const SizedBox(width: 8),
                Text('Se guarda como ${Categories.ingresos.name}',
                    style: text.bodyMedium),
              ],
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: TextStyle(color: scheme.error)),
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
            label: Text(_income ? 'Guardar ingreso' : 'Guardar gasto'),
          ),
        ],
      ),
    );
  }
}
