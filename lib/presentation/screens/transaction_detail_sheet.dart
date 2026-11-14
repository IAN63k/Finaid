import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/text_tools.dart';
import '../../domain/entities/bank.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/transaction.dart';
import '../widgets/common_widgets.dart';

Future<void> showTransactionDetail(BuildContext context, Transaction t) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => TransactionDetailSheet(transaction: t),
  );
}

enum _KindChoice { expense, income, ignore }

class TransactionDetailSheet extends ConsumerStatefulWidget {
  const TransactionDetailSheet({super.key, required this.transaction});

  final Transaction transaction;

  @override
  ConsumerState<TransactionDetailSheet> createState() =>
      _TransactionDetailSheetState();
}

class _TransactionDetailSheetState
    extends ConsumerState<TransactionDetailSheet> {
  late String _categoryId;
  late _KindChoice _kindChoice;
  bool _applyToMerchant = false;
  bool _saving = false;

  Transaction get t => widget.transaction;

  @override
  void initState() {
    super.initState();
    _categoryId = t.categoryId;
    _kindChoice = t.ignored
        ? _KindChoice.ignore
        : t.kind.isIncome
            ? _KindChoice.income
            : _KindChoice.expense;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final edits = ref.read(editUseCasesProvider);
    var current = t;

    final wantsIgnore = _kindChoice == _KindChoice.ignore;
    if (wantsIgnore != t.ignored) {
      await edits.setIgnored(current, wantsIgnore,
          applyToMerchant: _applyToMerchant);
      current = current.copyWith(ignored: wantsIgnore);
    }

    if (!wantsIgnore) {
      final wantsIncome = _kindChoice == _KindChoice.income;
      if (wantsIncome != current.kind.isIncome ||
          current.kind == TransactionKind.unknown) {
        final newKind = wantsIncome
            ? (current.kind.isIncome ? current.kind : TransactionKind.deposit)
            : (current.kind.isExpense
                ? current.kind
                : TransactionKind.purchase);
        await edits.changeKind(current, newKind);
        current = current.copyWith(kind: newKind);
        if (wantsIncome) _categoryId = Categories.ingresos.id;
      }
    }

    if (_categoryId != current.categoryId) {
      await edits.recategorize(current, _categoryId,
          applyToMerchant: _applyToMerchant);
    }

    await ref.read(transactionsProvider.notifier).reload();
    await ref.read(merchantRulesProvider.notifier).reload();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar movimiento'),
        content: const Text(
            'Se borrará de Finaid. Si el banco vuelve a notificarlo, se creará de nuevo.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(editUseCasesProvider).deleteTransaction(t);
    await ref.read(transactionsProvider.notifier).reload();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final bank = KnownBanks.byId(t.bankId);
    final merchant = t.merchantRaw.isEmpty
        ? 'Sin comercio detectado'
        : TextTools.titleCase(TextTools.merchantKey(t.merchantRaw));
    final categories = _kindChoice == _KindChoice.income
        ? [Categories.ingresos]
        : Categories.expenses;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CategoryAvatar(Categories.byId(_categoryId), radius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(merchant,
                        style: text.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    Text(
                      '${bank.name} · ${t.kind.label}'
                      '${t.accountHint != null ? ' · *${t.accountHint}' : ''}',
                      style: text.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    Text(Dates.shortDate(t.occurredAt),
                        style: text.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              MoneyText(t.amountMinor,
                  currency: t.currency,
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          if (t.needsReview)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'No estoy seguro de haber leído bien esta notificación. Revisa el tipo y la categoría.',
                style: text.bodySmall?.copyWith(color: scheme.error),
              ),
            ),
          const SizedBox(height: 20),
          Text('Tipo', style: text.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<_KindChoice>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                  value: _KindChoice.expense,
                  label: Text('Gasto'),
                  icon: Icon(Icons.arrow_upward, size: 16)),
              ButtonSegment(
                  value: _KindChoice.income,
                  label: Text('Ingreso'),
                  icon: Icon(Icons.arrow_downward, size: 16)),
              ButtonSegment(
                  value: _KindChoice.ignore,
                  label: Text('Ignorar'),
                  icon: Icon(Icons.visibility_off_outlined, size: 16)),
            ],
            selected: {_kindChoice},
            onSelectionChanged: (s) => setState(() {
              _kindChoice = s.first;
              if (_kindChoice == _KindChoice.income) {
                _categoryId = Categories.ingresos.id;
              } else if (_categoryId == Categories.ingresos.id) {
                _categoryId = Categories.otros.id;
              }
            }),
          ),
          if (_kindChoice == _KindChoice.ignore)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Los movimientos ignorados no cuentan en totales ni consejos. Útil para traspasos entre tus propias cuentas.',
                style:
                    text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: 20),
          Text('Categoría', style: text.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in categories)
                ChoiceChip(
                  avatar: Text(c.emoji),
                  label: Text(c.name),
                  selected: _categoryId == c.id,
                  onSelected: _kindChoice == _KindChoice.ignore
                      ? null
                      : (_) => setState(() => _categoryId = c.id),
                ),
            ],
          ),
          if (t.merchantKey.isNotEmpty) ...[
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _applyToMerchant,
              onChanged: (v) => setState(() => _applyToMerchant = v),
              title: Text('Aplicar siempre a $merchant'),
              subtitle: const Text(
                  'Guarda una regla y actualiza los movimientos anteriores de este comercio.'),
            ),
          ],
          const SizedBox(height: 16),
          _RawNotificationBox(rawId: t.rawNotificationId),
          const SizedBox(height: 24),
          Row(
            children: [
              TextButton.icon(
                onPressed: _saving ? null : _delete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Eliminar'),
                style: TextButton.styleFrom(foregroundColor: scheme.error),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check),
                label: const Text('Guardar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RawNotificationBox extends ConsumerWidget {
  const _RawNotificationBox({required this.rawId});

  final String? rawId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = rawId;
    if (id == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder(
      future: ref.read(rawNotificationRepositoryProvider).byId(id),
      builder: (context, snapshot) {
        final raw = snapshot.data;
        if (raw == null) return const SizedBox.shrink();
        return ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Notificación original'),
          subtitle: Text(raw.sourcePackage,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(raw.fullText,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        );
      },
    );
  }
}
