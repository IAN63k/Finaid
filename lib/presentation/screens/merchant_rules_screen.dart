import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../core/utils/text_tools.dart';
import '../../domain/entities/category.dart';
import '../widgets/common_widgets.dart';

class MerchantRulesScreen extends ConsumerWidget {
  const MerchantRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(merchantRulesProvider).valueOrNull ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Reglas por comercio')),
      body: rules.isEmpty
          ? const EmptyState(
              icon: Icons.rule,
              title: 'Sin reglas todavía',
              message:
                  'Abre un movimiento, cambia su categoría y activa "Aplicar siempre" para crear una.',
            )
          : ListView.separated(
              itemCount: rules.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final rule = rules[index];
                final category = rule.categoryId == null
                    ? null
                    : Categories.byId(rule.categoryId!);
                return ListTile(
                  leading: category == null
                      ? const CircleAvatar(
                          child: Icon(Icons.visibility_off_outlined))
                      : CategoryAvatar(category),
                  title: Text(TextTools.titleCase(rule.merchantKey)),
                  subtitle: Text([
                    if (category != null) category.name,
                    if (rule.ignore) 'Ignorado',
                  ].join(' · ')),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Eliminar regla',
                    onPressed: () =>
                        ref.read(merchantRulesProvider.notifier).remove(rule),
                  ),
                );
              },
            ),
    );
  }
}
