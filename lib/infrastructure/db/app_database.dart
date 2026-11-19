import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Base de datos local. Todo el historial vive en el dispositivo.
class AppDatabase {
  AppDatabase._();

  /// v2: pagos recurrentes (manuales y preferencias sobre los detectados).
  static const int version = 2;

  /// [path] permite abrir una ruta concreta (p. ej. `inMemoryDatabasePath` en
  /// tests con `sqflite_common_ffi`).
  static Future<Database> open({String? path}) async {
    final dbPath = path ?? p.join(await getDatabasesPath(), 'finaid.db');
    return openDatabase(
      dbPath,
      version: version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _create,
      onUpgrade: _upgrade,
    );
  }

  static Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await _createV2(db);
  }

  static Future<void> _createV2(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recurring_manual (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        amount_minor INTEGER NOT NULL,
        category_id TEXT NOT NULL,
        day_of_month INTEGER NOT NULL,
        remind INTEGER NOT NULL DEFAULT 1,
        last_paid_month INTEGER,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recurring_overrides (
        recurring_id TEXT PRIMARY KEY,
        dismissed INTEGER NOT NULL DEFAULT 0,
        remind INTEGER NOT NULL DEFAULT 1
      )
    ''');
  }

  static Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE raw_notifications (
        id TEXT PRIMARY KEY,
        source_package TEXT NOT NULL,
        title TEXT,
        body TEXT NOT NULL,
        posted_at INTEGER NOT NULL,
        channel TEXT NOT NULL,
        dedupe_key TEXT UNIQUE,
        status TEXT NOT NULL DEFAULT 'pending',
        reason TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        raw_id TEXT,
        amount_minor INTEGER NOT NULL,
        currency TEXT NOT NULL,
        kind TEXT NOT NULL,
        merchant_raw TEXT NOT NULL,
        merchant_key TEXT NOT NULL,
        bank_id TEXT NOT NULL,
        account_hint TEXT,
        occurred_at INTEGER NOT NULL,
        category_id TEXT NOT NULL,
        category_source TEXT NOT NULL,
        ignored INTEGER NOT NULL DEFAULT 0,
        confidence REAL NOT NULL,
        note TEXT
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_transactions_occurred ON transactions(occurred_at)');
    await db.execute(
        'CREATE INDEX idx_transactions_merchant ON transactions(merchant_key)');
    await db.execute('''
      CREATE TABLE merchant_rules (
        id TEXT PRIMARY KEY,
        merchant_key TEXT NOT NULL UNIQUE,
        category_id TEXT,
        ignore INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE budgets (
        category_id TEXT PRIMARY KEY,
        monthly_limit_minor INTEGER NOT NULL
      )
    ''');
    await _createV2(db);
  }
}
