import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../core/app_info.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../domain/backup/backup_payload.dart';
import '../../domain/export/transactions_csv.dart';
import '../../infrastructure/backup/backup_codec.dart';
import '../../infrastructure/platform/document_storage.dart';
import '../widgets/common_widgets.dart';

/// Respaldo cifrado, restauración y exportación a Excel (CSV).
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;

  // ---------------------------------------------------------------------------
  // Crear respaldo
  // ---------------------------------------------------------------------------

  Future<void> _createBackup() async {
    final choice = await showDialog<_PasswordChoice>(
      context: context,
      builder: (_) => const _NewPasswordDialog(),
    );
    if (choice == null || !mounted) return;

    final Uint8List bytes;
    final now = DateTime.now();
    try {
      bytes = await _withProgress('Creando respaldo…', () async {
        final payload = await ref.read(backupServiceProvider).collect(
              settings: ref.read(settingsProvider),
              appVersion: appVersionLabel,
              now: now,
            );
        return encodeBackupInBackground(payload, password: choice.password);
      });
    } catch (e, st) {
      debugPrint('Finaid: error creando respaldo: $e\n$st');
      _snack('No se pudo crear el respaldo. Inténtalo de nuevo y, si se repite, usa "Copiar diagnóstico".');
      return;
    }

    final saved = await _saveDocument(
      fileName: 'finaid-respaldo-${_stamp(now)}.json',
      mimeType: 'application/json',
      bytes: bytes,
    );
    if (saved == null) return;
    await ref.read(settingsProvider.notifier).markBackupCreated(now);
    _snack(choice.password == null
        ? 'Respaldo guardado (sin contraseña).'
        : 'Respaldo cifrado guardado. Sin la contraseña no se puede abrir.');
  }

  // ---------------------------------------------------------------------------
  // Restaurar
  // ---------------------------------------------------------------------------

  Future<PickedDocument?> _pickBackupFile() async {
    try {
      return await ref.read(documentStorageProvider).open(
        // Sin filtro: Drive y Samsung no siempre reportan un .json como
        // application/json. Si no es un respaldo, inspect() lo dice claramente.
        mimeTypes: const [],
      );
    } on DocumentStorageException catch (e) {
      _snack(e.message);
      return null;
    }
  }

  /// Descifra (pidiendo la contraseña si hace falta, con reintentos).
  Future<BackupPayload?> _decode(PickedDocument doc, BackupInfo info) async {
    while (true) {
      String? password;
      if (info.encrypted) {
        password = await showDialog<String>(
          context: context,
          builder: (_) => _AskPasswordDialog(fileName: doc.name),
        );
        if (password == null || !mounted) return null;
      }
      try {
        return await _withProgress(
          info.encrypted ? 'Descifrando…' : 'Leyendo respaldo…',
          () => decodeBackupInBackground(doc.bytes, password: password),
        );
      } on BackupException catch (e) {
        _snack(_errorText(e.error));
        if (e.error != BackupError.wrongPassword || !mounted) return null;
      }
    }
  }

  Future<void> _restore() async {
    final doc = await _pickBackupFile();
    if (doc == null || !mounted) return;

    final BackupInfo info;
    try {
      info = ref.read(backupCodecProvider).inspect(doc.bytes);
    } on BackupException catch (e) {
      _snack(_errorText(e.error));
      return;
    }

    final payload = await _decode(doc, info);
    if (payload == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.restore),
        title: const Text('Restaurar respaldo'),
        content: Text(
          'Respaldo del ${Dates.shortDate(payload.createdAt)}'
          '${payload.appVersion.isEmpty ? '' : ' (${payload.appVersion})'}:\n\n'
          '• ${payload.transactions.length} movimientos\n'
          '• ${payload.merchantRules.length} reglas por comercio\n'
          '• ${payload.budgets.length} presupuestos\n'
          '• ${payload.notifications.length} notificaciones recibidas\n\n'
          'Se combina con lo que ya tienes: nada se borra y restaurar dos veces no duplica movimientos.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restaurar')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final summary = await _withProgress('Restaurando…', () async {
        final s = await ref
            .read(backupServiceProvider)
            .restore(payload, current: ref.read(settingsProvider));
        await ref.read(settingsProvider.notifier).applyRestored(s.settings);
        await ref.read(transactionsProvider.notifier).reload();
        await ref.read(merchantRulesProvider.notifier).reload();
        ref.invalidate(budgetsProvider);
        return s;
      });
      _snack('Listo: ${summary.transactions} movimientos y '
          '${summary.merchantRules} reglas restaurados.');
    } catch (e) {
      _snack('No se pudo restaurar: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Exportar CSV
  // ---------------------------------------------------------------------------

  Future<void> _exportCsv() async {
    final month = ref.read(selectedMonthProvider);
    final all = ref.read(allTransactionsProvider);
    final scope = await showDialog<_ExportScope>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('¿Qué movimientos exportar?'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, _ExportScope.month),
            child: ListTile(
              leading: const Icon(Icons.calendar_month),
              title: Text(Dates.monthLabel(month)),
              subtitle: const Text('El mes que tienes seleccionado'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, _ExportScope.all),
            child: ListTile(
              leading: const Icon(Icons.all_inclusive),
              title: const Text('Todos'),
              subtitle: Text('${all.length} movimientos'),
            ),
          ),
        ],
      ),
    );
    if (scope == null || !mounted) return;

    final list = scope == _ExportScope.all
        ? all
        : all.where((t) => Dates.sameMonth(t.occurredAt, month)).toList();
    if (list.isEmpty) {
      _snack('No hay movimientos para exportar.');
      return;
    }
    final csv = TransactionsCsv.build(list);
    final name = scope == _ExportScope.all
        ? 'finaid-movimientos-${_stamp(DateTime.now())}.csv'
        : 'finaid-movimientos-${month.year}-${month.month.toString().padLeft(2, '0')}.csv';
    final saved = await _saveDocument(
      fileName: name,
      mimeType: 'text/csv',
      bytes: Uint8List.fromList(utf8.encode(csv)),
    );
    if (saved != null) {
      _snack('${list.length} movimientos exportados. Ábrelo con Excel o Google Sheets.');
    }
  }

  // ---------------------------------------------------------------------------
  // Utilidades
  // ---------------------------------------------------------------------------

  Future<String?> _saveDocument({
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    try {
      return await ref
          .read(documentStorageProvider)
          .save(fileName: fileName, mimeType: mimeType, bytes: bytes);
    } on DocumentStorageException catch (e) {
      _snack(e.message);
      return null;
    }
  }

  Future<T> _withProgress<T>(String label, Future<T> Function() task) async {
    setState(() => _busy = true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 3)),
              const SizedBox(width: 16),
              Expanded(child: Text(label)),
            ],
          ),
        ),
      ),
    );
    try {
      return await task();
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _busy = false);
      }
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  static String _stamp(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _errorText(BackupError e) => switch (e) {
        BackupError.notABackup => 'Ese archivo no es un respaldo de Finaid.',
        BackupError.unsupportedVersion =>
          'El respaldo es de una versión más nueva de Finaid. Actualiza la app.',
        BackupError.passwordRequired => 'El respaldo está protegido con contraseña.',
        BackupError.wrongPassword => 'Contraseña incorrecta. Inténtalo de nuevo.',
        BackupError.corrupted => 'El respaldo está dañado o incompleto.',
      };

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final count = ref.watch(allTransactionsProvider).length;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final last = settings.lastBackupAt;
    final stale = last == null || DateTime.now().difference(last).inDays >= 30;

    return Scaffold(
      appBar: AppBar(title: const Text('Respaldo y exportación')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(
              'Tus movimientos solo están en este teléfono. Un respaldo te permite '
              'recuperarlos si cambias o pierdes el celular.',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SectionTitle('Respaldo'),
            Card(
              elevation: 0,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      stale ? Icons.history_toggle_off : Icons.verified_outlined,
                      color: stale ? AppTheme.warning(context) : AppTheme.income(context),
                    ),
                    title: Text(last == null
                        ? 'Nunca has creado un respaldo'
                        : 'Último respaldo: ${Dates.shortDate(last)}'),
                    subtitle: Text('$count movimientos en este teléfono'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.backup_outlined),
                    title: const Text('Crear respaldo'),
                    subtitle: const Text(
                        'Movimientos, reglas, presupuestos, ajustes y notificaciones recibidas. '
                        'Lo guardas donde quieras: Drive, Descargas, tu computador.'),
                    onTap: _createBackup,
                  ),
                  ListTile(
                    leading: const Icon(Icons.restore),
                    title: const Text('Restaurar respaldo'),
                    subtitle: const Text(
                        'Combina un respaldo con lo que ya tienes, sin borrar ni duplicar.'),
                    onTap: _restore,
                  ),
                ],
              ),
            ),
            const SectionTitle('Exportar'),
            Card(
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.table_view_outlined),
                title: const Text('Exportar a Excel (CSV)'),
                subtitle: const Text(
                    'Un archivo por mes o con todo, listo para Excel o Google Sheets.'),
                onTap: _exportCsv,
              ),
            ),
            const SectionTitle('Bueno saber'),
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '• Con contraseña, el respaldo se cifra con AES-256. Si la olvidas, '
                  'nadie puede recuperarlo, ni siquiera Finaid.\n'
                  '• Sin contraseña, cualquiera que tenga el archivo puede leer tus movimientos.\n'
                  '• Android también puede respaldar Finaid en tu cuenta de Google si tienes '
                  'activada la copia de seguridad del teléfono, pero no siempre se restaura al '
                  'cambiar de celular: el respaldo manual es la forma segura.',
                  style: text.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant, height: 1.45),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ExportScope { month, all }

class _PasswordChoice {
  const _PasswordChoice(this.password);

  /// `null` = sin cifrar.
  final String? password;
}

class _NewPasswordDialog extends StatefulWidget {
  const _NewPasswordDialog();

  @override
  State<_NewPasswordDialog> createState() => _NewPasswordDialogState();
}

class _NewPasswordDialogState extends State<_NewPasswordDialog> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _protect = true;
  bool _obscure = true;
  String? _error;

  static const int minLength = 6;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_protect) {
      Navigator.pop(context, const _PasswordChoice(null));
      return;
    }
    if (_password.text.length < minLength) {
      setState(() => _error = 'Usa al menos $minLength caracteres.');
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = 'Las contraseñas no coinciden.');
      return;
    }
    Navigator.pop(context, _PasswordChoice(_password.text));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Crear respaldo'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _protect,
              onChanged: (v) => setState(() {
                _protect = v;
                _error = null;
              }),
              title: const Text('Proteger con contraseña'),
              subtitle: const Text('Recomendado si lo guardas en la nube.'),
            ),
            if (_protect) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _password,
                obscureText: _obscure,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirm,
                obscureText: _obscure,
                decoration: const InputDecoration(labelText: 'Repite la contraseña'),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 8),
              Text(
                'Si la olvidas no hay forma de recuperar el respaldo.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: scheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _submit, child: const Text('Continuar')),
      ],
    );
  }
}

class _AskPasswordDialog extends StatefulWidget {
  const _AskPasswordDialog({this.fileName});

  final String? fileName;

  @override
  State<_AskPasswordDialog> createState() => _AskPasswordDialogState();
}

class _AskPasswordDialogState extends State<_AskPasswordDialog> {
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Respaldo protegido'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.fileName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(widget.fileName!,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          TextField(
            controller: _password,
            obscureText: _obscure,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Contraseña del respaldo',
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
            onPressed: () => Navigator.pop(context, _password.text),
            child: const Text('Abrir')),
      ],
    );
  }
}
