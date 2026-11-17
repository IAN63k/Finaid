import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../domain/entities/bank.dart';
import '../../domain/ports/repositories.dart';
import '../widgets/common_widgets.dart';
import '../widgets/ignore_reason_label.dart';

/// Diagnóstico: qué notificaciones llegaron a Finaid y qué se hizo con cada una.
/// Si una compra real no aparece aquí, el problema es la captura (permiso,
/// package, servicio); si aparece como "Ignorada", es el parser.
class CaptureLogScreen extends ConsumerStatefulWidget {
  const CaptureLogScreen({super.key});

  @override
  ConsumerState<CaptureLogScreen> createState() => _CaptureLogScreenState();
}

class _CaptureLogScreenState extends ConsumerState<CaptureLogScreen> {
  late Future<List<RawNotificationRecord>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<RawNotificationRecord>> _load() =>
      ref.read(rawNotificationRepositoryProvider).recent(limit: 150);

  void _reload() => setState(() => _future = _load());

  Future<void> _reprocess() async {
    setState(() => _busy = true);
    final created = await ref.read(ingestUseCaseProvider).reprocessIgnored();
    if (created > 0) {
      await ref.read(transactionsProvider.notifier).reload();
    }
    if (!mounted) return;
    setState(() => _busy = false);
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(created == 0
          ? 'Ninguna de las ignoradas se entiende todavía'
          : '$created movimiento${created == 1 ? '' : 's'} recuperado${created == 1 ? '' : 's'}'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones recibidas'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<List<RawNotificationRecord>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final records = snapshot.data!;
          if (records.isEmpty) {
            return const EmptyState(
              icon: Icons.inbox_outlined,
              title: 'Todavía no ha llegado ninguna notificación',
              message:
                  'Si acabas de recibir una de tu banco y no aparece aquí, revisa en Ajustes el estado del servicio y "Apps detectadas".',
            );
          }
          final ignored = records.where((r) => r.status == 'ignored').length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text(
                'Aquí ves todo lo que Finaid recibió de las apps activadas y qué hizo con cada notificación. Si una aparece como "Ignorada" por error, toca "Reprocesar" después de actualizar la app, o cópiala y envíala para mejorar el parser.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              if (ignored > 0)
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : _reprocess,
                  icon: const Icon(Icons.replay),
                  label: Text('Reprocesar $ignored ignorada${ignored == 1 ? '' : 's'}'),
                ),
              const SizedBox(height: 8),
              for (final r in records) _RecordCard(record: r),
            ],
          );
        },
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record});

  final RawNotificationRecord record;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final n = record.notification;
    final bank = KnownBanks.byPackage(n.sourcePackage);
    final source = bank?.name ??
        (KnownBanks.smsPackages.contains(n.sourcePackage)
            ? 'SMS'
            : n.sourcePackage);
    final (color, icon) = switch (record.status) {
      'parsed' => (AppTheme.income(context), Icons.check_circle_outline),
      'ignored' => (AppTheme.warning(context), Icons.block),
      'duplicate' => (scheme.outline, Icons.copy_all_outlined),
      _ => (scheme.outline, Icons.hourglass_empty),
    };
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Text(statusLabel(record.status),
                    style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(
                  '$source · ${Dates.shortDate(n.postedAt)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            if (record.status != 'parsed')
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(ignoreReasonLabel(record.reason),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ),
            const SizedBox(height: 8),
            SelectableText(n.fullText,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
