import 'package:flutter/material.dart';

import '../../core/utils/date_utils.dart';
import '../../core/utils/money_format.dart';
import '../../core/utils/text_tools.dart';
import '../../domain/entities/bank.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/insight.dart';
import '../../domain/entities/transaction.dart';
import '../../core/theme/app_theme.dart';

class MoneyText extends StatelessWidget {
  const MoneyText(
    this.minor, {
    super.key,
    this.currency = 'COP',
    this.style,
    this.color,
    this.prefix = '',
  });

  final int minor;
  final String currency;
  final TextStyle? style;
  final Color? color;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.bodyLarge;
    return Text(
      '$prefix${MoneyFormat.format(minor, currency: currency)}',
      style: base?.copyWith(
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar(this.category, {super.key, this.radius = 20, this.dim = false});

  final Category category;
  final double radius;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final color = Color(category.color);
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withAlpha(dim ? 30 : 46),
      child: Text(category.emoji, style: TextStyle(fontSize: radius * 0.95)),
    );
  }
}

class MonthSelector extends StatelessWidget {
  const MonthSelector({
    super.key,
    required this.month,
    required this.onPrevious,
    required this.onNext,
    this.canGoNext = true,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool canGoNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Mes anterior',
        ),
        Text(Dates.monthLabel(month),
            style: Theme.of(context).textTheme.titleMedium),
        IconButton(
          onPressed: canGoNext ? onNext : null,
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Mes siguiente',
        ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: scheme.outline),
            const SizedBox(height: 16),
            Text(title,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class InsightCard extends StatelessWidget {
  const InsightCard(this.insight, {super.key, this.compact = false});

  final Insight insight;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (insight.severity) {
      InsightSeverity.warning => (Icons.warning_amber_rounded, AppTheme.warning(context)),
      InsightSeverity.positive => (Icons.celebration_outlined, AppTheme.income(context)),
      InsightSeverity.info => (Icons.lightbulb_outline, scheme.primary),
    };
    final category =
        insight.categoryId == null ? null : Categories.byId(insight.categoryId!);
    return Card(
      elevation: 0,
      color: color.withAlpha(22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withAlpha(60)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(insight.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    insight.body,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant, height: 1.35),
                    maxLines: compact ? 2 : null,
                    overflow: compact ? TextOverflow.ellipsis : null,
                  ),
                  if (category != null && !compact) ...[
                    const SizedBox(height: 8),
                    Chip(
                      avatar: Text(category.emoji),
                      label: Text(category.name),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TransactionTile extends StatelessWidget {
  const TransactionTile(this.transaction, {super.key, this.onTap});

  final Transaction transaction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final category = Categories.byId(t.categoryId);
    final bank = KnownBanks.byId(t.bankId);
    final scheme = Theme.of(context).colorScheme;
    final merchant = t.merchantRaw.isEmpty
        ? t.kind.label
        : TextTools.titleCase(TextTools.merchantKey(t.merchantRaw));
    // Ingresos y devoluciones: entra dinero.
    final isIncome = t.kind.isInflow;
    final amountColor = t.ignored
        ? scheme.outline
        : isIncome
            ? AppTheme.income(context)
            : AppTheme.expense(context);
    final subtitleParts = <String>[
      bank.name,
      if (t.merchantRaw.isNotEmpty) t.kind.label,
      Dates.timeLabel(t.occurredAt),
      if (t.accountHint != null) '*${t.accountHint}',
    ];

    return ListTile(
      onTap: onTap,
      leading: CategoryAvatar(category, dim: t.ignored),
      title: Text(
        merchant,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          decoration: t.ignored ? TextDecoration.lineThrough : null,
          color: t.ignored ? scheme.outline : null,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(subtitleParts.join(' · '),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (t.needsReview)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(Icons.help_outline,
                  size: 16, color: AppTheme.warning(context)),
            ),
        ],
      ),
      trailing: MoneyText(
        t.amountMinor,
        currency: t.currency,
        prefix: isIncome ? '+' : (t.kind.isExpense ? '-' : ''),
        color: amountColor,
        style: Theme.of(context)
            .textTheme
            .bodyLarge
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
