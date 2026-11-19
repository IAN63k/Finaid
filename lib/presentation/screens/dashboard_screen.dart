import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money_format.dart';
import '../../domain/analytics/month_summary.dart';
import '../../domain/budgets/budget_check.dart';
import '../../domain/entities/category.dart';
import '../widgets/common_widgets.dart';
import '../widgets/finaid_logo.dart';
import 'manual_transaction_sheet.dart';
import 'transaction_detail_sheet.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({
    super.key,
    required this.onSeeTransactions,
    required this.onSeeInsights,
    required this.onOpenSettings,
  });

  final VoidCallback onSeeTransactions;
  final VoidCallback onSeeInsights;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(monthSummaryProvider);
    final insights = ref.watch(insightsProvider).take(3).toList();
    final permission = ref.watch(permissionStatusProvider);
    final month = ref.watch(selectedMonthProvider);
    final monthNotifier = ref.read(selectedMonthProvider.notifier);
    final loading = ref.watch(transactionsProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FinaidLogo(size: 30),
            SizedBox(width: 10),
            Text('Finaid', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Registrar a mano',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => showManualTransactionSheet(context),
          ),
          IconButton(
            tooltip: 'Buscar pendientes',
            icon: const Icon(Icons.sync),
            onPressed: () async {
              final n = await ref.read(ingestionServiceProvider).drainAll();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(n == 0
                    ? 'No había notificaciones pendientes'
                    : '$n movimiento${n == 1 ? '' : 's'} nuevo${n == 1 ? '' : 's'}'),
              ));
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(ingestionServiceProvider).drainAll();
          await ref.read(transactionsProvider.notifier).reload();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            if (permission.valueOrNull == false)
              _PermissionBanner(onTap: onOpenSettings),
            MonthSelector(
              month: month,
              onPrevious: monthNotifier.previous,
              onNext: monthNotifier.next,
              canGoNext: !monthNotifier.isCurrentMonth,
            ),
            if (loading) const LinearProgressIndicator(minHeight: 2),
            _SummaryCard(summary: summary),
            if (summary.byCategory.isNotEmpty) ...[
              const SectionTitle('Por categoría'),
              _CategoryBreakdown(
                summary: summary,
                budgets: ref.watch(budgetsProvider).valueOrNull ?? const {},
              ),
            ],
            if (insights.isNotEmpty) ...[
              SectionTitle(
                'Consejos',
                trailing: TextButton(
                    onPressed: onSeeInsights, child: const Text('Ver todos')),
              ),
              for (final i in insights)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: onSeeInsights,
                    child: InsightCard(i, compact: true),
                  ),
                ),
            ],
            SectionTitle(
              'Últimos movimientos',
              trailing: TextButton(
                  onPressed: onSeeTransactions, child: const Text('Ver todos')),
            ),
            if (summary.transactions.isEmpty)
              const EmptyState(
                icon: Icons.notifications_none,
                title: 'Sin movimientos este mes',
                message:
                    'Cuando llegue una notificación de tu banco aparecerá aquí automáticamente.',
              )
            else
              Card(
                elevation: 0,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final t in summary.transactions.take(5))
                      TransactionTile(
                        t,
                        onTap: () => showTransactionDetail(context, t),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.warning(context);
    return Card(
      elevation: 0,
      color: color.withAlpha(26),
      margin: const EdgeInsets.only(top: 8),
      child: ListTile(
        leading: Icon(Icons.notifications_off_outlined, color: color),
        title: const Text('Falta el acceso a notificaciones'),
        subtitle: const Text(
            'Sin él, Finaid no puede detectar tus compras. Toca para activarlo.'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      elevation: 0,
      color: scheme.primaryContainer,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gastos del mes',
                style: text.labelLarge
                    ?.copyWith(color: scheme.onPrimaryContainer)),
            const SizedBox(height: 4),
            MoneyText(
              summary.expensesMinor,
              style: text.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    label: 'Ingresos',
                    value: MoneyFormat.compact(summary.incomeMinor),
                  ),
                ),
                Expanded(
                  child: _Stat(
                    label: 'Balance',
                    value: MoneyFormat.compact(summary.balanceMinor),
                  ),
                ),
                Expanded(
                  child: _Stat(
                    label: 'Movimientos',
                    value: '${summary.movementCount}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: text.labelSmall?.copyWith(color: scheme.onPrimaryContainer)),
        Text(value,
            style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w700, color: scheme.onPrimaryContainer)),
      ],
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.summary, required this.budgets});

  final MonthSummary summary;
  final Map<String, int> budgets;

  @override
  Widget build(BuildContext context) {
    final entries = summary.categoriesSorted.take(6).toList();
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            for (final e in entries) ...[
              _CategoryRow(
                category: Categories.byId(e.key),
                amountMinor: e.value,
                share: summary.shareOf(e.key),
                limitMinor: budgets[e.key],
              ),
              if (e != entries.last) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

/// Una categoría del mes. Si tiene presupuesto, la barra muestra el avance
/// contra el límite (ámbar desde el 80%, rojo al superarlo); si no, su parte
/// del gasto total.
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.amountMinor,
    required this.share,
    this.limitMinor,
  });

  final Category category;
  final int amountMinor;
  final double share;
  final int? limitMinor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final limit = limitMinor ?? 0;
    final hasBudget = limit > 0;
    final ratio = hasBudget ? amountMinor / limit : share;

    final Color color;
    if (!hasBudget) {
      color = Color(category.color);
    } else if (ratio >= 1) {
      color = scheme.error;
    } else if (ratio >= BudgetCheck.warningRatio) {
      color = AppTheme.warning(context);
    } else {
      color = Color(category.color);
    }

    return Row(
      children: [
        CategoryAvatar(category, radius: 16),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(category.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  MoneyText(amountMinor,
                      style: text.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 42,
                    child: Text(
                      MoneyFormat.percent(ratio),
                      textAlign: TextAlign.end,
                      style: text.bodySmall?.copyWith(
                        color: hasBudget ? color : scheme.onSurfaceVariant,
                        fontWeight: hasBudget ? FontWeight.w700 : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0.0, 1.0).toDouble(),
                  minHeight: 6,
                  color: color,
                  backgroundColor: color.withAlpha(36),
                ),
              ),
              if (hasBudget)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    amountMinor > limit
                        ? 'Presupuesto de ${MoneyFormat.format(limit)} superado por ${MoneyFormat.format(amountMinor - limit)}'
                        : 'De ${MoneyFormat.format(limit)} · quedan ${MoneyFormat.format(limit - amountMinor)}',
                    style: text.labelSmall?.copyWith(
                        color: ratio >= BudgetCheck.warningRatio
                            ? color
                            : scheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
