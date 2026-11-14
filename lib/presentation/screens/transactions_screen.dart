import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../core/utils/date_utils.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/transaction.dart';
import '../widgets/common_widgets.dart';
import 'transaction_detail_sheet.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String? _categoryFilter;
  bool _onlyReview = false;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(monthSummaryProvider);
    final month = ref.watch(selectedMonthProvider);
    final monthNotifier = ref.read(selectedMonthProvider.notifier);

    final presentCategories = <String>{
      for (final t in summary.transactions) t.categoryId,
    };
    final filtered = summary.transactions.where((t) {
      if (_categoryFilter != null && t.categoryId != _categoryFilter) {
        return false;
      }
      if (_onlyReview && !t.needsReview) return false;
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        return t.merchantRaw.toLowerCase().contains(q) ||
            t.merchantKey.toLowerCase().contains(q) ||
            t.bankId.contains(q);
      }
      return true;
    }).toList();

    final items = _groupByDay(filtered);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Movimientos'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: Column(
            children: [
              MonthSelector(
                month: month,
                onPrevious: monthNotifier.previous,
                onNext: monthNotifier.next,
                canGoNext: !monthNotifier.isCurrentMonth,
              ),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: const Text('Por revisar'),
                        avatar: const Icon(Icons.help_outline, size: 16),
                        selected: _onlyReview,
                        onSelected: (v) => setState(() => _onlyReview = v),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: const Text('Todas'),
                        selected: _categoryFilter == null,
                        onSelected: (_) =>
                            setState(() => _categoryFilter = null),
                      ),
                    ),
                    for (final c in Categories.all
                        .where((c) => presentCategories.contains(c.id)))
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          avatar: Text(c.emoji),
                          label: Text(c.name),
                          selected: _categoryFilter == c.id,
                          onSelected: (_) => setState(() =>
                              _categoryFilter =
                                  _categoryFilter == c.id ? null : c.id),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Buscar comercio o banco',
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _query = ''),
                      ),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Nada por aquí',
                    message:
                        'No hay movimientos que coincidan con los filtros en este mes.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      if (item is DateTime) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                          child: Text(
                            Dates.dayLabel(item),
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant),
                          ),
                        );
                      }
                      final t = item as Transaction;
                      return TransactionTile(
                        t,
                        onTap: () => showTransactionDetail(context, t),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<Object> _groupByDay(List<Transaction> list) {
    final groups = <DateTime, List<Transaction>>{};
    for (final t in list) {
      groups.putIfAbsent(Dates.dayStart(t.occurredAt), () => []).add(t);
    }
    final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    final out = <Object>[];
    for (final d in days) {
      out.add(d);
      out.addAll(groups[d]!);
    }
    return out;
  }
}
