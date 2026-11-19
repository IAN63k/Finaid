import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/money_format.dart';
import '../../domain/analytics/monthly_trends.dart';
import '../../domain/entities/category.dart';
import '../widgets/common_widgets.dart';
import '../widgets/monthly_bar_chart.dart';

/// Tendencia mensual del gasto: últimos 6 o 12 meses, por categoría, con
/// promedio, mes más alto, proyección y cambios por categoría.
class TrendsScreen extends ConsumerStatefulWidget {
  const TrendsScreen({super.key});

  @override
  ConsumerState<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends ConsumerState<TrendsScreen> {
  int _months = 6;
  String? _categoryId;
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(allTransactionsProvider);
    final now = DateTime.now();
    final trends = MonthlyTrends.compute(all,
        now: now, months: _months, categoryId: _categoryId);
    final selected = (_selected ?? trends.points.length - 1)
        .clamp(0, trends.points.length - 1)
        .toInt();
    final point = trends.points[selected];
    final changes = _categoryId == null
        ? CategoryChange.compute(all, now: now)
        : const <CategoryChange>[];
    final usedCategories = {
      for (final t in all)
        if (t.countsAsExpense) t.categoryId,
    };
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final hasData = trends.points.any((p) => p.expensesMinor > 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Tendencias')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          // Filtros en una sola fila: periodo y categoría.
          Row(
            children: [
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 6, label: Text('6 meses')),
                  ButtonSegment(value: 12, label: Text('12 meses')),
                ],
                selected: {_months},
                onSelectionChanged: (s) => setState(() {
                  _months = s.first;
                  _selected = null;
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _categoryId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('Todas')),
                    for (final c in Categories.expenses
                        .where((c) => usedCategories.contains(c.id)))
                      DropdownMenuItem<String?>(
                          value: c.id,
                          child: Text('${c.emoji} ${c.name}',
                              overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() {
                    _categoryId = v;
                    _selected = null;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasData)
            const EmptyState(
              icon: Icons.bar_chart,
              title: 'Aún no hay datos para comparar',
              message:
                  'Cuando tengas gastos de al menos un mes completo verás aquí cómo cambian mes a mes.',
            )
          else ...[
            _StatsRow(trends: trends, now: now),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        _categoryId == null
                            ? 'Gastos por mes'
                            : 'Gastos por mes · ${Categories.byId(_categoryId!).name}',
                        style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 8),
                    MonthlyBarChart(
                      points: trends.points,
                      averageMinor: trends.averageMinor,
                      selectedIndex: selected,
                      onSelect: (i) => setState(() => _selected = i),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        '* Mes en curso (parcial). Línea punteada: promedio de los meses cerrados. Toca una barra para ver el detalle.',
                        style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            _MonthDetail(point: point, average: trends.averageMinor),
            if (changes.isNotEmpty) ...[
              const SectionTitle('Este mes frente a tus últimos 3'),
              Text(
                'Comparado a esta misma altura del mes (día ${now.day}).',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                child: Column(
                  children: [
                    for (final c in changes.take(6))
                      _ChangeTile(change: c),
                  ],
                ),
              ),
            ],
            const SectionTitle('Detalle por mes'),
            _MonthsTable(points: trends.points.reversed.toList()),
          ],
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.trends, required this.now});

  final MonthlyTrends trends;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final vs = trends.projectionVsAverage;
    final highest = trends.highest;
    return Row(
      children: [
        Expanded(
          child: _Stat(
            label: 'Promedio mensual',
            value: trends.averageMinor > 0
                ? MoneyFormat.compact(trends.averageMinor)
                : '—',
            caption: trends.closedMonthsWithData == 0
                ? 'sin meses cerrados'
                : '${trends.closedMonthsWithData} mes${trends.closedMonthsWithData == 1 ? '' : 'es'}',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Stat(
            label: 'Mes más alto',
            value: highest == null ? '—' : MoneyFormat.compact(highest.expensesMinor),
            caption: highest == null ? '' : Dates.monthLabel(highest.month),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Stat(
            label: 'Cierre estimado',
            value: MoneyFormat.compact(trends.projectionMinor),
            caption: vs == null
                ? Dates.monthLabel(now)
                : '${vs >= 0 ? '↑' : '↓'} ${MoneyFormat.percent(vs.abs())} vs promedio',
            warn: vs != null && vs > 0.1,
            good: vs != null && vs < -0.05,
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.caption,
    this.warn = false,
    this.good = false,
  });

  final String label;
  final String value;
  final String caption;
  final bool warn;
  final bool good;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final captionColor = warn
        ? AppTheme.warning(context)
        : good
            ? AppTheme.income(context)
            : scheme.onSurfaceVariant;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(value,
                style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()])),
            Text(caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelSmall?.copyWith(
                    color: captionColor,
                    fontWeight: warn || good ? FontWeight.w700 : null)),
          ],
        ),
      ),
    );
  }
}

class _MonthDetail extends StatelessWidget {
  const _MonthDetail({required this.point, required this.average});

  final MonthPoint point;
  final int average;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final diff = average > 0 && !point.isCurrent
        ? (point.expensesMinor - average) / average
        : null;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${Dates.monthLabel(point.month)}${point.isCurrent ? ' (en curso)' : ''}',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                Text('Gastos ${MoneyFormat.format(point.expensesMinor)}'),
                Text('Ingresos ${MoneyFormat.format(point.incomeMinor)}'),
                Text('${point.expenseCount} gasto${point.expenseCount == 1 ? '' : 's'}'),
              ],
            ),
            if (diff != null) ...[
              const SizedBox(height: 4),
              Text(
                diff >= 0
                    ? '${MoneyFormat.percent(diff)} por encima de tu promedio'
                    : '${MoneyFormat.percent(-diff)} por debajo de tu promedio',
                style: text.bodySmall?.copyWith(
                    color: diff > 0.1
                        ? AppTheme.warning(context)
                        : scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChangeTile extends StatelessWidget {
  const _ChangeTile({required this.change});

  final CategoryChange change;

  @override
  Widget build(BuildContext context) {
    final category = Categories.byId(change.categoryId);
    final scheme = Theme.of(context).colorScheme;
    final ratio = change.ratio;
    final up = change.differenceMinor > 0;
    final color = ratio == null
        ? scheme.onSurfaceVariant
        : up
            ? AppTheme.warning(context)
            : AppTheme.income(context);
    final trend = ratio == null
        ? 'Nuevo este mes'
        : '${up ? '↑' : '↓'} ${MoneyFormat.percent(ratio.abs())}';
    return ListTile(
      leading: CategoryAvatar(category, radius: 16),
      title: Text(category.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
          '${MoneyFormat.format(change.currentMinor)} vs ${MoneyFormat.format(change.averageMinor)} promedio'),
      trailing: Text(trend,
          style: TextStyle(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

/// Vista de tabla: los mismos datos del gráfico, accesibles sin color.
class _MonthsTable extends StatelessWidget {
  const _MonthsTable({required this.points});

  final List<MonthPoint> points;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    TextStyle? figures([bool bold = false]) => text.bodyMedium?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
        fontWeight: bold ? FontWeight.w700 : null);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(1.4),
            1: FlexColumnWidth(1.2),
            2: FlexColumnWidth(1.2),
            3: FlexColumnWidth(1.2),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              children: [
                for (final h in const ['Mes', 'Gastos', 'Ingresos', 'Balance'])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(h,
                        textAlign: h == 'Mes' ? TextAlign.start : TextAlign.end,
                        style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ),
              ],
            ),
            for (final p in points)
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                        '${Dates.monthNamesEs[p.month.month - 1].substring(0, 3)} ${p.month.year}${p.isCurrent ? '*' : ''}'),
                  ),
                  Text(MoneyFormat.compact(p.expensesMinor),
                      textAlign: TextAlign.end, style: figures(true)),
                  Text(MoneyFormat.compact(p.incomeMinor),
                      textAlign: TextAlign.end, style: figures()),
                  Text(MoneyFormat.compact(p.balanceMinor),
                      textAlign: TextAlign.end,
                      style: figures()?.copyWith(
                          color: p.balanceMinor < 0 ? scheme.error : null)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
