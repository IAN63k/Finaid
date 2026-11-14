import 'package:sqflite/sqflite.dart' hide Transaction;

import '../../domain/entities/merchant_rule.dart';
import '../../domain/entities/raw_notification.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/ports/repositories.dart';

class SqfliteTransactionRepository implements TransactionRepository {
  SqfliteTransactionRepository(this._db);

  final Database _db;
  static const _table = 'transactions';

  @override
  Future<List<Transaction>> all() async {
    final rows = await _db.query(_table, orderBy: 'occurred_at DESC');
    return rows.map(_fromRow).toList();
  }

  @override
  Future<Transaction?> byId(String id) async {
    final rows = await _db.query(_table, where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  @override
  Future<List<Transaction>> byMerchantKey(String merchantKey) async {
    final rows = await _db
        .query(_table, where: 'merchant_key = ?', whereArgs: [merchantKey]);
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<Transaction>> findSimilar({
    required int amountMinor,
    required DateTime around,
    required Duration window,
  }) async {
    final from = around.subtract(window).millisecondsSinceEpoch;
    final to = around.add(window).millisecondsSinceEpoch;
    final rows = await _db.query(
      _table,
      where: 'amount_minor = ? AND occurred_at BETWEEN ? AND ?',
      whereArgs: [amountMinor, from, to],
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> save(Transaction transaction) => _db.insert(
        _table,
        _toRow(transaction),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  @override
  Future<void> saveAll(List<Transaction> transactions) async {
    if (transactions.isEmpty) return;
    final batch = _db.batch();
    for (final t in transactions) {
      batch.insert(_table, _toRow(t),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> delete(String id) =>
      _db.delete(_table, where: 'id = ?', whereArgs: [id]);

  static Map<String, Object?> _toRow(Transaction t) => {
        'id': t.id,
        'raw_id': t.rawNotificationId,
        'amount_minor': t.amountMinor,
        'currency': t.currency,
        'kind': t.kind.name,
        'merchant_raw': t.merchantRaw,
        'merchant_key': t.merchantKey,
        'bank_id': t.bankId,
        'account_hint': t.accountHint,
        'occurred_at': t.occurredAt.millisecondsSinceEpoch,
        'category_id': t.categoryId,
        'category_source': t.categorySource.name,
        'ignored': t.ignored ? 1 : 0,
        'confidence': t.confidence,
        'note': t.note,
      };

  static Transaction _fromRow(Map<String, Object?> r) => Transaction(
        id: r['id'] as String,
        rawNotificationId: r['raw_id'] as String?,
        amountMinor: r['amount_minor'] as int,
        currency: r['currency'] as String,
        kind: TransactionKindX.fromName(r['kind'] as String),
        merchantRaw: r['merchant_raw'] as String,
        merchantKey: r['merchant_key'] as String,
        bankId: r['bank_id'] as String,
        accountHint: r['account_hint'] as String?,
        occurredAt:
            DateTime.fromMillisecondsSinceEpoch(r['occurred_at'] as int),
        categoryId: r['category_id'] as String,
        categorySource:
            CategorySourceX.fromName(r['category_source'] as String),
        ignored: (r['ignored'] as int) == 1,
        confidence: (r['confidence'] as num).toDouble(),
        note: r['note'] as String?,
      );
}

class SqfliteRawNotificationRepository implements RawNotificationRepository {
  SqfliteRawNotificationRepository(this._db);

  final Database _db;
  static const _table = 'raw_notifications';

  @override
  Future<bool> existsByDedupeKey(String dedupeKey) async {
    final rows = await _db.query(_table,
        columns: ['id'], where: 'dedupe_key = ?', whereArgs: [dedupeKey]);
    return rows.isNotEmpty;
  }

  @override
  Future<RawNotification?> byId(String id) async {
    final rows = await _db.query(_table, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return RawNotification(
      id: r['id'] as String,
      sourcePackage: r['source_package'] as String,
      title: r['title'] as String?,
      text: r['body'] as String,
      postedAt: DateTime.fromMillisecondsSinceEpoch(r['posted_at'] as int),
      channel: NotificationChannelX.fromName(r['channel'] as String),
      dedupeKey: r['dedupe_key'] as String?,
    );
  }

  @override
  Future<void> save(RawNotification n) => _db.insert(
        _table,
        {
          'id': n.id,
          'source_package': n.sourcePackage,
          'title': n.title,
          'body': n.text,
          'posted_at': n.postedAt.millisecondsSinceEpoch,
          'channel': n.channel.name,
          'dedupe_key': n.dedupeKey,
          'status': 'pending',
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

  @override
  Future<void> markProcessed(String id,
          {required String status, String? reason}) =>
      _db.update(_table, {'status': status, 'reason': reason},
          where: 'id = ?', whereArgs: [id]);

  @override
  Future<int> count() async =>
      Sqflite.firstIntValue(
          await _db.rawQuery('SELECT COUNT(*) FROM $_table')) ??
      0;
}

class SqfliteMerchantRuleRepository implements MerchantRuleRepository {
  SqfliteMerchantRuleRepository(this._db);

  final Database _db;
  static const _table = 'merchant_rules';

  @override
  Future<List<MerchantRule>> all() async {
    final rows = await _db.query(_table, orderBy: 'created_at DESC');
    return rows.map(_fromRow).toList();
  }

  @override
  Future<MerchantRule?> byMerchantKey(String merchantKey) async {
    final rows = await _db
        .query(_table, where: 'merchant_key = ?', whereArgs: [merchantKey]);
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  @override
  Future<void> upsert(MerchantRule rule) => _db.insert(
        _table,
        {
          'id': rule.id,
          'merchant_key': rule.merchantKey,
          'category_id': rule.categoryId,
          'ignore': rule.ignore ? 1 : 0,
          'created_at': rule.createdAt.millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  @override
  Future<void> delete(String id) =>
      _db.delete(_table, where: 'id = ?', whereArgs: [id]);

  static MerchantRule _fromRow(Map<String, Object?> r) => MerchantRule(
        id: r['id'] as String,
        merchantKey: r['merchant_key'] as String,
        categoryId: r['category_id'] as String?,
        ignore: (r['ignore'] as int) == 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
      );
}

class SqfliteBudgetRepository implements BudgetRepository {
  SqfliteBudgetRepository(this._db);

  final Database _db;
  static const _table = 'budgets';

  @override
  Future<Map<String, int>> all() async {
    final rows = await _db.query(_table);
    return {
      for (final r in rows)
        r['category_id'] as String: r['monthly_limit_minor'] as int,
    };
  }

  @override
  Future<void> set(String categoryId, int monthlyLimitMinor) => _db.insert(
        _table,
        {'category_id': categoryId, 'monthly_limit_minor': monthlyLimitMinor},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  @override
  Future<void> remove(String categoryId) =>
      _db.delete(_table, where: 'category_id = ?', whereArgs: [categoryId]);
}
