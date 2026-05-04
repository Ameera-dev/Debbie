import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'tables.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static const _dbName = 'debbie.db';
  static const _dbVersion = 11;

  static DatabaseHelper? _instance;
  static Database? _database;

  static DatabaseHelper get instance {
    _instance ??= DatabaseHelper._();
    return _instance!;
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    for (final sql in Tables.allCreateStatements) {
      batch.execute(sql);
    }
    await batch.commit(noResult: true);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _migrateV1toV2(db);
    }
    if (oldVersion < 3) {
      await _migrateV2toV3(db);
    }
    if (oldVersion < 4) {
      await _migrateV3toV4(db);
    }
    if (oldVersion < 5) {
      await _migrateV4toV5(db);
    }
    if (oldVersion < 6) {
      await _migrateV5toV6(db);
    }
    if (oldVersion < 7) {
      await _migrateV6toV7(db);
    }
    if (oldVersion < 8) {
      await _migrateV7toV8(db);
    }
    if (oldVersion < 9) {
      await _migrateV8toV9(db);
    }
    if (oldVersion < 10) {
      await _migrateV9toV10(db);
    }
    if (oldVersion < 11) {
      await _migrateV10toV11(db);
    }
  }

  /// v1 → v2: replace single `category TEXT` with `tags TEXT` (JSON array).
  Future<void> _migrateV1toV2(Database db) async {
    await db.execute('''
      ALTER TABLE ${Tables.transactions} RENAME TO _transactions_v1
    ''');
    // At v1→v2, createTransactions still had the flat schema with tags
    await db.execute('''
      CREATE TABLE ${Tables.transactions} (
        id TEXT PRIMARY KEY,
        amount INTEGER NOT NULL,
        type TEXT NOT NULL,
        description TEXT NOT NULL,
        tags TEXT,
        value_id TEXT REFERENCES ${Tables.userValues}(id) ON DELETE SET NULL,
        goal_id TEXT REFERENCES ${Tables.goals}(id) ON DELETE SET NULL,
        date TEXT NOT NULL,
        notes TEXT,
        image_path TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');
    await db.execute('''
      INSERT INTO ${Tables.transactions}
        (id, amount, type, description, tags, value_id, goal_id,
         date, notes, image_path, created_at)
      SELECT
        id, amount, type, description,
        CASE
          WHEN category IS NULL THEN NULL
          ELSE '["' || category || '"]'
        END,
        value_id, goal_id, date, notes, image_path, created_at
      FROM _transactions_v1
    ''');
    await db.execute('DROP TABLE _transactions_v1');
  }

  /// v2 → v3: extract item-level fields from transactions into transaction_items.
  /// Each existing transaction becomes one session + one item.
  Future<void> _migrateV2toV3(Database db) async {
    await db.execute('PRAGMA foreign_keys = OFF');
    try {
      await db.execute(
        'ALTER TABLE ${Tables.transactions} RENAME TO _transactions_v2',
      );
      await db.execute(Tables.createTransactions);
      await db.execute(Tables.createTransactionItems);

      // Copy session-level data
      await db.execute('''
        INSERT INTO ${Tables.transactions} (id, type, date, notes, image_path, created_at)
        SELECT id, type, date, notes, image_path, created_at
        FROM _transactions_v2
      ''');

      // Each old row becomes one item; reuse the same id for the item
      await db.execute('''
        INSERT INTO ${Tables.transactionItems}
          (id, transaction_id, description, amount, tags, value_id, goal_id, created_at)
        SELECT id, id, description, amount, tags, value_id, goal_id, created_at
        FROM _transactions_v2
      ''');

      await db.execute('DROP TABLE _transactions_v2');
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
    }
  }

  /// v4 → v5: add title column to transactions.
  Future<void> _migrateV4toV5(Database db) async {
    await db.execute(
      'ALTER TABLE ${Tables.transactions} ADD COLUMN title TEXT',
    );
  }

  /// v5 → v6: add weekly check-in structure to journal entries.
  Future<void> _migrateV5toV6(Database db) async {
    await db.execute(
      'ALTER TABLE ${Tables.journal} ADD COLUMN entry_type TEXT NOT NULL DEFAULT \'legacy_entry\'',
    );
    await db.execute(
      'ALTER TABLE ${Tables.journal} ADD COLUMN period_start TEXT',
    );
  }

  /// v6 → v7: add mindfulness fields and daily intentions.
  Future<void> _migrateV6toV7(Database db) async {
    await db.execute(
      'ALTER TABLE ${Tables.transactions} ADD COLUMN status TEXT NOT NULL DEFAULT \'recorded\'',
    );
    await db.execute(
      'ALTER TABLE ${Tables.transactions} ADD COLUMN pending_until TEXT',
    );
    await db.execute(
      'ALTER TABLE ${Tables.transactions} ADD COLUMN emotion TEXT',
    );
    await db.execute(
      'ALTER TABLE ${Tables.userValues} ADD COLUMN guardian_text TEXT',
    );
    await db.execute(Tables.createDailyIntentions);
  }

  /// v3 → v4: add ai_response to journal, create ai_reflections table.
  Future<void> _migrateV3toV4(Database db) async {
    await db.execute(
      'ALTER TABLE ${Tables.journal} ADD COLUMN ai_response TEXT',
    );
    await db.execute(Tables.createAiReflections);
  }

  /// v9 → v10: create transaction_images table and migrate existing image_path values.
  Future<void> _migrateV9toV10(Database db) async {
    await db.execute(Tables.createTransactionImages);
    // Migrate existing single image_path values into the new table
    await db.execute('''
      INSERT INTO ${Tables.transactionImages} (id, transaction_id, image_path, sort_order, created_at)
      SELECT lower(hex(randomblob(4)) || '-' || hex(randomblob(2)) || '-4' ||
             substr(hex(randomblob(2)),2) || '-' ||
             substr('89ab',abs(random()) % 4 + 1, 1) ||
             substr(hex(randomblob(2)),2) || '-' || hex(randomblob(6))),
             id, image_path, 0, created_at
      FROM ${Tables.transactions}
      WHERE image_path IS NOT NULL
    ''');
  }

  /// v8 → v9: add location fields to transactions.
  Future<void> _migrateV8toV9(Database db) async {
    await db.execute(
      'ALTER TABLE ${Tables.transactions} ADD COLUMN latitude REAL',
    );
    await db.execute(
      'ALTER TABLE ${Tables.transactions} ADD COLUMN longitude REAL',
    );
    await db.execute(
      'ALTER TABLE ${Tables.transactions} ADD COLUMN location_label TEXT',
    );
  }

  /// v7 → v8: add recurring expenses and payments tables.
  Future<void> _migrateV7toV8(Database db) async {
    await db.execute(Tables.createRecurringExpenses);
    await db.execute(Tables.createRecurringExpensePayments);
  }

  /// v10 → v11: add daily plan/actualization rows for weekly budgeting.
  Future<void> _migrateV10toV11(Database db) async {
    await db.execute(Tables.createWeeklyBudgetPlans);
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  Future<T> withTransaction<T>(
    Future<T> Function(Transaction txn) action,
  ) async {
    final db = await database;
    return db.transaction(action);
  }
}
