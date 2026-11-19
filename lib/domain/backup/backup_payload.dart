import '../entities/merchant_rule.dart';
import '../entities/raw_notification.dart';
import '../entities/transaction.dart';
import '../ports/repositories.dart';
import '../recurring/recurring.dart';

/// Ajustes que viajan en el respaldo (sin depender de la capa de infraestructura).
class BackupSettings {
  const BackupSettings({
    this.notifyCaptures = true,
    this.expectedMonthlyIncomeMinor,
    this.enabledPackages = const [],
    this.disabledPackages = const [],
  });

  final bool notifyCaptures;
  final int? expectedMonthlyIncomeMinor;
  final List<String> enabledPackages;
  final List<String> disabledPackages;

  Map<String, Object?> toJson() => {
        'notify_captures': notifyCaptures,
        'expected_monthly_income_minor': expectedMonthlyIncomeMinor,
        'enabled_packages': enabledPackages,
        'disabled_packages': disabledPackages,
      };

  factory BackupSettings.fromJson(Map<String, Object?> j) => BackupSettings(
        notifyCaptures: j['notify_captures'] as bool? ?? true,
        expectedMonthlyIncomeMinor:
            (j['expected_monthly_income_minor'] as num?)?.toInt(),
        enabledPackages: _strings(j['enabled_packages']),
        disabledPackages: _strings(j['disabled_packages']),
      );
}

/// Todo lo que el usuario tiene en Finaid, listo para serializar.
class BackupPayload {
  const BackupPayload({
    required this.createdAt,
    required this.appVersion,
    required this.transactions,
    required this.merchantRules,
    required this.budgets,
    required this.notifications,
    required this.settings,
    this.manualRecurring = const [],
    this.recurringOverrides = const [],
  });

  /// Versión del formato de los datos. Subirla solo con cambios incompatibles
  /// y mantener la lectura de versiones anteriores.
  static const int schemaVersion = 1;

  final DateTime createdAt;
  final String appVersion;
  final List<Transaction> transactions;
  final List<MerchantRule> merchantRules;

  /// categoryId → límite mensual en unidades menores.
  final Map<String, int> budgets;
  final List<RawNotificationRecord> notifications;
  final BackupSettings settings;

  /// Pagos recurrentes agregados a mano (desde 0.8.0; vacío en respaldos viejos).
  final List<ManualRecurring> manualRecurring;

  /// Preferencias sobre pagos detectados (desde 0.8.0).
  final List<RecurringOverride> recurringOverrides;

  Map<String, Object?> toJson() => {
        'schema': schemaVersion,
        'created_at': createdAt.toIso8601String(),
        'app_version': appVersion,
        'transactions': [for (final t in transactions) _txToJson(t)],
        'merchant_rules': [for (final r in merchantRules) _ruleToJson(r)],
        'budgets': budgets,
        'notifications': [for (final n in notifications) _rawToJson(n)],
        'settings': settings.toJson(),
        'recurring_manual': [for (final m in manualRecurring) _manualToJson(m)],
        'recurring_overrides': [
          for (final o in recurringOverrides)
            {
              'recurring_id': o.recurringId,
              'dismissed': o.dismissed,
              'remind': o.remind,
            },
        ],
      };

  factory BackupPayload.fromJson(Map<String, Object?> j) {
    final schema = (j['schema'] as num?)?.toInt() ?? 0;
    if (schema < 1 || schema > schemaVersion) {
      throw FormatException('Versión de respaldo no soportada: $schema');
    }
    return BackupPayload(
      createdAt: DateTime.parse(j['created_at'] as String),
      appVersion: j['app_version'] as String? ?? '',
      transactions: [
        for (final t in _maps(j['transactions'])) _txFromJson(t),
      ],
      merchantRules: [
        for (final r in _maps(j['merchant_rules'])) _ruleFromJson(r),
      ],
      budgets: {
        for (final e in ((j['budgets'] as Map?) ?? const {}).entries)
          '${e.key}': (e.value as num).toInt(),
      },
      notifications: [
        for (final n in _maps(j['notifications'])) _rawFromJson(n),
      ],
      settings: BackupSettings.fromJson(
          Map<String, Object?>.from((j['settings'] as Map?) ?? const {})),
      manualRecurring: [
        for (final m in _maps(j['recurring_manual'])) _manualFromJson(m),
      ],
      recurringOverrides: [
        for (final o in _maps(j['recurring_overrides']))
          RecurringOverride(
            recurringId: o['recurring_id'] as String,
            dismissed: o['dismissed'] as bool? ?? false,
            remind: o['remind'] as bool? ?? true,
          ),
      ],
    );
  }

  static Map<String, Object?> _manualToJson(ManualRecurring m) => {
        'id': m.id,
        'name': m.name,
        'amount_minor': m.amountMinor,
        'category_id': m.categoryId,
        'day_of_month': m.dayOfMonth,
        'remind': m.remind,
        'last_paid_month': m.lastPaidMonth?.toIso8601String(),
        'created_at': m.createdAt.toIso8601String(),
      };

  static ManualRecurring _manualFromJson(Map<String, Object?> j) =>
      ManualRecurring(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        amountMinor: (j['amount_minor'] as num).toInt(),
        categoryId: j['category_id'] as String? ?? 'otros',
        dayOfMonth: (j['day_of_month'] as num?)?.toInt() ?? 1,
        remind: j['remind'] as bool? ?? true,
        lastPaidMonth: j['last_paid_month'] == null
            ? null
            : DateTime.parse(j['last_paid_month'] as String),
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  static Map<String, Object?> _txToJson(Transaction t) => {
        'id': t.id,
        'raw_id': t.rawNotificationId,
        'amount_minor': t.amountMinor,
        'currency': t.currency,
        'kind': t.kind.name,
        'merchant_raw': t.merchantRaw,
        'merchant_key': t.merchantKey,
        'bank_id': t.bankId,
        'account_hint': t.accountHint,
        'occurred_at': t.occurredAt.toIso8601String(),
        'category_id': t.categoryId,
        'category_source': t.categorySource.name,
        'ignored': t.ignored,
        'confidence': t.confidence,
        'note': t.note,
      };

  static Transaction _txFromJson(Map<String, Object?> j) => Transaction(
        id: j['id'] as String,
        rawNotificationId: j['raw_id'] as String?,
        amountMinor: (j['amount_minor'] as num).toInt(),
        currency: j['currency'] as String? ?? 'COP',
        kind: TransactionKindX.fromName(j['kind'] as String? ?? ''),
        merchantRaw: j['merchant_raw'] as String? ?? '',
        merchantKey: j['merchant_key'] as String? ?? '',
        bankId: j['bank_id'] as String? ?? 'desconocido',
        accountHint: j['account_hint'] as String?,
        occurredAt: DateTime.parse(j['occurred_at'] as String),
        categoryId: j['category_id'] as String? ?? 'otros',
        categorySource:
            CategorySourceX.fromName(j['category_source'] as String? ?? ''),
        ignored: j['ignored'] as bool? ?? false,
        confidence: (j['confidence'] as num?)?.toDouble() ?? 1.0,
        note: j['note'] as String?,
      );

  static Map<String, Object?> _ruleToJson(MerchantRule r) => {
        'id': r.id,
        'merchant_key': r.merchantKey,
        'category_id': r.categoryId,
        'ignore': r.ignore,
        'created_at': r.createdAt.toIso8601String(),
      };

  static MerchantRule _ruleFromJson(Map<String, Object?> j) => MerchantRule(
        id: j['id'] as String,
        merchantKey: j['merchant_key'] as String,
        categoryId: j['category_id'] as String?,
        ignore: j['ignore'] as bool? ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  static Map<String, Object?> _rawToJson(RawNotificationRecord r) => {
        'id': r.notification.id,
        'source_package': r.notification.sourcePackage,
        'title': r.notification.title,
        'text': r.notification.text,
        'posted_at': r.notification.postedAt.toIso8601String(),
        'channel': r.notification.channel.name,
        'dedupe_key': r.notification.dedupeKey,
        'status': r.status,
        'reason': r.reason,
      };

  static RawNotificationRecord _rawFromJson(Map<String, Object?> j) =>
      RawNotificationRecord(
        notification: RawNotification(
          id: j['id'] as String,
          sourcePackage: j['source_package'] as String? ?? '',
          title: j['title'] as String?,
          text: j['text'] as String? ?? '',
          postedAt: DateTime.parse(j['posted_at'] as String),
          channel: NotificationChannelX.fromName(j['channel'] as String? ?? ''),
          dedupeKey: j['dedupe_key'] as String?,
        ),
        status: j['status'] as String? ?? 'pending',
        reason: j['reason'] as String?,
      );
}

List<Map<String, Object?>> _maps(Object? value) => [
      for (final e in (value as List?) ?? const [])
        Map<String, Object?>.from(e as Map),
    ];

List<String> _strings(Object? value) =>
    [for (final e in (value as List?) ?? const []) '$e'];
