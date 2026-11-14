import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/entities/insight.dart';
import '../widgets/common_widgets.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(insightsProvider);
    final warnings =
        insights.where((i) => i.severity == InsightSeverity.warning).toList();
    final rest =
        insights.where((i) => i.severity != InsightSeverity.warning).toList();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Consejos')),
      body: insights.isEmpty
          ? const EmptyState(
              icon: Icons.lightbulb_outline,
              title: 'Todavía no hay consejos',
              message:
                  'Con unos días de movimientos empezarán a aparecer recomendaciones sobre tu gasto.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(
                  'Generados en tu teléfono a partir de tus movimientos. Nada sale del dispositivo.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                if (warnings.isNotEmpty) ...[
                  const SectionTitle('Para mirar ya'),
                  for (final i in warnings)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InsightCard(i),
                    ),
                ],
                if (rest.isNotEmpty) ...[
                  const SectionTitle('Hallazgos'),
                  for (final i in rest)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InsightCard(i),
                    ),
                ],
              ],
            ),
    );
  }
}
