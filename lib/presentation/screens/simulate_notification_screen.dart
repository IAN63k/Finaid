import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../application/providers.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/money_format.dart';
import '../../core/utils/text_tools.dart';
import '../../domain/entities/bank.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/raw_notification.dart';
import '../../domain/parsing/parse_result.dart';
import '../../domain/usecases/ingest_notification.dart';

class _Sample {
  const _Sample(this.label, this.package, this.title, this.text);

  final String label;
  final String package;
  final String title;
  final String text;
}

const List<_Sample> _samples = [
  _Sample(
    'Bancolombia compra',
    'com.todo1.mobile',
    'Bancolombia',
    'Bancolombia le informa Compra por \$45.900,00 en EXITO CALLE 80 a las 14:33. 12/11/2026 T.Cred *1234. Inquietudes al 6045109095.',
  ),
  _Sample(
    'Nequi compra',
    'com.nequi.MobileApp',
    'Nequi',
    'Compraste \$25.000 en RAPPI con tu tarjeta Nequi *4321. Tu saldo ahora es \$150.000.',
  ),
  _Sample(
    'Nequi envío',
    'com.nequi.MobileApp',
    'Nequi',
    '¡Listo! Enviaste \$30.000 a Juan Perez. Tu saldo es \$120.000.',
  ),
  _Sample(
    'DaviPlata ingreso',
    'com.davivienda.daviplataapp',
    'DaviPlata',
    'Te llegaron \$200.000 de MARIA LOPEZ. Saldo: \$350.000',
  ),
  _Sample(
    'Nu suscripción',
    'com.nu.production',
    'Nu',
    'Compra aprobada: \$35.900 en NETFLIX.COM con tu tarjeta de crédito Nu terminada en 5678.',
  ),
  _Sample(
    'Davivienda factura',
    'com.davivienda.daviviendaapp',
    'Davivienda',
    'Davivienda: Pago de factura CLARO por \$89.900 realizado exitosamente desde tu cuenta *9876 el 10/11/2026 a las 09:12.',
  ),
  _Sample(
    'SMS clave (se ignora)',
    'com.google.android.apps.messaging',
    'Bancolombia',
    'Bancolombia: Tu clave dinámica es 482913. No la compartas con nadie.',
  ),
];

class SimulateNotificationScreen extends ConsumerStatefulWidget {
  const SimulateNotificationScreen({super.key});

  @override
  ConsumerState<SimulateNotificationScreen> createState() =>
      _SimulateNotificationScreenState();
}

class _SimulateNotificationScreenState
    extends ConsumerState<SimulateNotificationScreen> {
  final _title = TextEditingController();
  final _text = TextEditingController();
  String _package = KnownBanks.bancolombia.packages.first;
  ParseOutcome? _preview;
  IngestResult? _result;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  RawNotification _buildRaw() => RawNotification(
        id: const Uuid().v4(),
        sourcePackage: _package,
        title: _title.text.trim().isEmpty ? null : _title.text.trim(),
        text: _text.text.trim(),
        postedAt: DateTime.now(),
        channel: NotificationChannel.manual,
      );

  void _analyze() {
    if (_text.text.trim().isEmpty) return;
    setState(() {
      _result = null;
      _preview = ref.read(parserRegistryProvider).parse(_buildRaw());
    });
  }

  Future<void> _ingest() async {
    if (_text.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final result = await ref.read(ingestUseCaseProvider).call(_buildRaw());
    if (result.isNewTransaction) {
      await ref.read(transactionsProvider.notifier).reload();
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _preview = null;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final packages = <String, String>{
      for (final b in KnownBanks.all) b.packages.first: b.name,
      KnownBanks.smsPackages.first: 'Mensajes (SMS)',
      'otro.banco': 'Otro / desconocido',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Simular notificación')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Pega aquí el texto de una notificación o SMS de tu banco. Sirve para probar sin esperar una compra real y para reportar formatos que no se entienden.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _samples)
                ActionChip(
                  label: Text(s.label),
                  onPressed: () => setState(() {
                    _package = packages.containsKey(s.package)
                        ? s.package
                        : 'otro.banco';
                    _title.text = s.title;
                    _text.text = s.text;
                    _preview = null;
                    _result = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: packages.containsKey(_package) ? _package : 'otro.banco',
            decoration: const InputDecoration(labelText: 'App de origen'),
            items: [
              for (final e in packages.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _package = v ?? _package),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Título (opcional)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
                labelText: 'Texto de la notificación', alignLabelWithHint: true),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _analyze,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Solo analizar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _ingest,
                  icon: const Icon(Icons.add),
                  label: const Text('Registrar'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_preview != null) _OutcomeCard.preview(_preview!),
          if (_result != null) _OutcomeCard.result(_result!),
        ],
      ),
    );
  }
}

class _OutcomeCard extends StatelessWidget {
  const _OutcomeCard._({
    required this.title,
    required this.rows,
    required this.positive,
  });

  factory _OutcomeCard.preview(ParseOutcome outcome) {
    final t = outcome.transaction;
    if (t == null) {
      return _OutcomeCard._(
        title: 'Se ignoraría',
        rows: {'Motivo': _reasonLabel(outcome.ignoreReason)},
        positive: false,
      );
    }
    return _OutcomeCard._(
      title: 'Así se interpreta (sin guardar)',
      rows: {
        'Monto': MoneyFormat.format(t.amountMinor, currency: t.currency),
        'Tipo': t.kind.label,
        'Comercio': t.merchantRaw.isEmpty
            ? '—'
            : TextTools.titleCase(TextTools.merchantKey(t.merchantRaw)),
        'Banco': KnownBanks.byId(t.bankId).name,
        'Fecha': Dates.shortDate(t.occurredAt),
        if (t.accountHint != null) 'Cuenta/tarjeta': '*${t.accountHint}',
        'Confianza': MoneyFormat.percent(t.confidence),
      },
      positive: true,
    );
  }

  factory _OutcomeCard.result(IngestResult result) {
    final t = result.transaction;
    if (t == null) {
      final dup = result.status == IngestStatus.duplicate;
      return _OutcomeCard._(
        title: dup ? 'Ya estaba registrado' : 'Se ignoró',
        rows: {'Motivo': _reasonLabel(result.reason)},
        positive: false,
      );
    }
    final category = Categories.byId(t.categoryId);
    return _OutcomeCard._(
      title: 'Movimiento registrado',
      rows: {
        'Monto': MoneyFormat.format(t.amountMinor, currency: t.currency),
        'Tipo': t.kind.label,
        'Comercio': t.merchantRaw.isEmpty
            ? '—'
            : TextTools.titleCase(TextTools.merchantKey(t.merchantRaw)),
        'Categoría': '${category.emoji} ${category.name}',
        'Banco': KnownBanks.byId(t.bankId).name,
        'Fecha': Dates.shortDate(t.occurredAt),
        'Confianza': MoneyFormat.percent(t.confidence),
      },
      positive: true,
    );
  }

  final String title;
  final Map<String, String> rows;
  final bool positive;

  static String _reasonLabel(String? reason) => switch (reason) {
        'codigo_seguridad' => 'Es un código de seguridad / OTP',
        'rechazada' => 'Transacción rechazada o fallida',
        'promocion' => 'Parece una promoción',
        'recordatorio' => 'Es un recordatorio de pago',
        'seguridad' => 'Aviso de seguridad (inicio de sesión, bloqueo...)',
        'sin_monto' => 'No se encontró un monto',
        'sin_verbo' => 'No parece una compra, pago o transferencia',
        'notificacion_repetida' => 'La misma notificación ya se había procesado',
        'movimiento_repetido' =>
          'Ya existe un movimiento igual (push + SMS del mismo banco)',
        _ => reason ?? 'Desconocido',
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = positive ? scheme.primary : scheme.error;
    return Card(
      elevation: 0,
      color: color.withAlpha(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withAlpha(70)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 8),
            for (final e in rows.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(e.key,
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                    ),
                    Expanded(
                      child: Text(e.value,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
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
