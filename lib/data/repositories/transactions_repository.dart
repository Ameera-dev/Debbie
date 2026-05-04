import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../database/tables.dart';
import '../models/transaction_item_model.dart';
import '../models/transaction_model.dart';

class TransactionsRepository {
  const TransactionsRepository(this._db);

  final DatabaseHelper _db;

  // ---------------------------------------------------------------------------
  // Fetch helpers
  // ---------------------------------------------------------------------------

  /// Attach items to a list of sessions using a single bulk query.
  Future<List<TransactionModel>> _attachItems(
    Database db,
    List<TransactionModel> sessions,
  ) async {
    if (sessions.isEmpty) return sessions;
    final ids = sessions.map((s) => s.id).toList();
    final placeholders = List.filled(ids.length, '?').join(',');
    final itemRows = await db.rawQuery(
      'SELECT * FROM ${Tables.transactionItems} '
      'WHERE transaction_id IN ($placeholders) '
      'ORDER BY created_at ASC',
      ids,
    );
    final itemsByTx = <String, List<TransactionItemModel>>{};
    for (final row in itemRows) {
      final item = TransactionItemModel.fromMap(row);
      itemsByTx
          .putIfAbsent(item.transactionId, () => <TransactionItemModel>[])
          .add(item);
    }
    return sessions
        .map(
          (s) => s.copyWith(items: itemsByTx[s.id] ?? <TransactionItemModel>[]),
        )
        .toList();
  }

  /// Attach image paths to a list of sessions using a single bulk query.
  Future<List<TransactionModel>> _attachImages(
    Database db,
    List<TransactionModel> sessions,
  ) async {
    if (sessions.isEmpty) return sessions;
    final ids = sessions.map((s) => s.id).toList();
    final placeholders = List.filled(ids.length, '?').join(',');
    final imageRows = await db.rawQuery(
      'SELECT transaction_id, image_path FROM ${Tables.transactionImages} '
      'WHERE transaction_id IN ($placeholders) '
      'ORDER BY sort_order ASC, created_at ASC',
      ids,
    );
    final imagesByTx = <String, List<String>>{};
    for (final row in imageRows) {
      final txId = row['transaction_id'] as String;
      imagesByTx.putIfAbsent(txId, () => []).add(row['image_path'] as String);
    }
    return sessions
        .map((s) => s.copyWith(images: imagesByTx[s.id] ?? <String>[]))
        .toList();
  }

  Future<List<TransactionModel>> _attachAll(
    Database db,
    List<TransactionModel> sessions,
  ) async {
    final withItems = await _attachItems(db, sessions);
    return _attachImages(db, withItems);
  }

  // ---------------------------------------------------------------------------
  // Read operations
  // ---------------------------------------------------------------------------

  Future<List<TransactionModel>> getAll({
    String? type,
    DateTime? from,
    DateTime? to,
    String? search, // searches item descriptions
    bool includePending = false,
  }) async {
    final db = await _db.database;

    final whereClauses = <String>[];
    final args = <dynamic>[];

    if (type != null) {
      whereClauses.add('t.type = ?');
      args.add(type);
    }
    if (!includePending) {
      whereClauses.add('t.status = ?');
      args.add(TransactionModel.recordedStatus);
    }
    if (from != null) {
      whereClauses.add('t.date >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      whereClauses.add('t.date <= ?');
      args.add(to.toIso8601String());
    }

    String whereClause = whereClauses.isEmpty
        ? ''
        : 'WHERE ${whereClauses.join(' AND ')}';

    // If searching, match against title and item descriptions
    List<Map<String, dynamic>> rows;
    if (search != null && search.isNotEmpty) {
      rows = await db.rawQuery(
        '''
        SELECT DISTINCT t.*
        FROM ${Tables.transactions} t
        LEFT JOIN ${Tables.transactionItems} ti ON ti.transaction_id = t.id
        $whereClause
        ${whereClauses.isEmpty ? 'WHERE' : 'AND'} (t.title LIKE ? OR ti.description LIKE ?)
        ORDER BY t.date DESC, t.created_at DESC
        ''',
        [...args, '%$search%', '%$search%'],
      );
    } else {
      rows = await db.rawQuery('''
        SELECT * FROM ${Tables.transactions} t
        $whereClause
        ORDER BY t.date DESC, t.created_at DESC
        ''', args.isEmpty ? null : args);
    }

    final sessions = rows.map(TransactionModel.fromMap).toList();
    return _attachAll(db, sessions);
  }

  Future<List<TransactionModel>> getForMonth(String month) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '''
      SELECT * FROM ${Tables.transactions}
      WHERE strftime('%Y-%m', date) = ?
        AND status = ?
      ORDER BY date DESC, created_at DESC
      ''',
      [month, TransactionModel.recordedStatus],
    );
    final sessions = rows.map(TransactionModel.fromMap).toList();
    return _attachAll(db, sessions);
  }

  Future<TransactionModel?> getById(String id) async {
    final db = await _db.database;
    final rows = await db.query(
      Tables.transactions,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final session = TransactionModel.fromMap(rows.first);
    final sessions = await _attachItems(db, [session]);
    return sessions.first;
  }

  Future<List<TransactionModel>> getPendingExpenses() async {
    final db = await _db.database;
    final rows = await db.query(
      Tables.transactions,
      where: 'status = ? AND type = ?',
      whereArgs: [TransactionModel.pendingStatus, 'expense'],
      orderBy: 'pending_until ASC, date DESC, created_at DESC',
    );
    final sessions = rows.map(TransactionModel.fromMap).toList();
    return _attachAll(db, sessions);
  }

  // ---------------------------------------------------------------------------
  // Write operations
  // ---------------------------------------------------------------------------

  /// Insert a session, its items, and its images atomically.
  Future<void> insertSession(
    TransactionModel session,
    List<TransactionItemModel> items,
  ) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.insert(
        Tables.transactions,
        session.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (final item in items) {
        await txn.insert(
          Tables.transactionItems,
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (int i = 0; i < session.images.length; i++) {
        await txn.insert(
          Tables.transactionImages,
          {
            'id': '${session.id}_img_$i',
            'transaction_id': session.id,
            'image_path': session.images[i],
            'sort_order': i,
            'created_at': session.createdAt.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Update a session, replacing all its items and images atomically.
  Future<void> updateSession(
    TransactionModel session,
    List<TransactionItemModel> items,
  ) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.update(
        Tables.transactions,
        session.toMap(),
        where: 'id = ?',
        whereArgs: [session.id],
      );
      await txn.delete(
        Tables.transactionItems,
        where: 'transaction_id = ?',
        whereArgs: [session.id],
      );
      for (final item in items) {
        await txn.insert(
          Tables.transactionItems,
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await txn.delete(
        Tables.transactionImages,
        where: 'transaction_id = ?',
        whereArgs: [session.id],
      );
      for (int i = 0; i < session.images.length; i++) {
        await txn.insert(
          Tables.transactionImages,
          {
            'id': '${session.id}_img_$i',
            'transaction_id': session.id,
            'image_path': session.images[i],
            'sort_order': i,
            'created_at': session.createdAt.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    // Items cascade-delete via FK ON DELETE CASCADE
    await db.delete(Tables.transactions, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> confirmPending(String id) async {
    final db = await _db.database;
    await db.update(
      Tables.transactions,
      {'status': TransactionModel.recordedStatus, 'pending_until': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------------------------------------------------------------------------
  // Aggregate / analytics queries
  // ---------------------------------------------------------------------------

  Future<int> getTotalForMonth(String month, String type) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(ti.amount), 0) AS total
      FROM ${Tables.transactionItems} ti
      JOIN ${Tables.transactions} t ON t.id = ti.transaction_id
      WHERE t.type = ? AND strftime('%Y-%m', t.date) = ?
        AND t.status = ?
      ''',
      [type, month, TransactionModel.recordedStatus],
    );
    return rows.first['total'] as int? ?? 0;
  }

  /// All-time total for a transaction type — no date filter.
  Future<int> getAllTimeTotal(String type) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(ti.amount), 0) AS total
      FROM ${Tables.transactionItems} ti
      JOIN ${Tables.transactions} t ON t.id = ti.transaction_id
      WHERE t.type = ? AND t.status = ?
      ''',
      [type, TransactionModel.recordedStatus],
    );
    return rows.first['total'] as int? ?? 0;
  }

  /// Total within an arbitrary date range.
  Future<int> getTotalForRange(
    String type,
    DateTime from,
    DateTime to,
  ) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(ti.amount), 0) AS total
      FROM ${Tables.transactionItems} ti
      JOIN ${Tables.transactions} t ON t.id = ti.transaction_id
      WHERE t.type = ? AND t.status = ?
        AND t.date >= ? AND t.date <= ?
      ''',
      [
        type,
        TransactionModel.recordedStatus,
        from.toIso8601String(),
        to.toIso8601String(),
      ],
    );
    return rows.first['total'] as int? ?? 0;
  }

  Future<Map<String, int>> getSpendingByValue(String month) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '''
      SELECT ti.value_id, SUM(ti.amount) AS total
      FROM ${Tables.transactionItems} ti
      JOIN ${Tables.transactions} t ON t.id = ti.transaction_id
      WHERE t.type = 'expense'
        AND t.status = ?
        AND ti.value_id IS NOT NULL
        AND strftime('%Y-%m', t.date) = ?
      GROUP BY ti.value_id
      ''',
      [TransactionModel.recordedStatus, month],
    );
    return {
      for (final r in rows) r['value_id'] as String: (r['total'] as int? ?? 0),
    };
  }

  Future<List<String>> getDistinctDescriptions() async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT ti.description '
      'FROM ${Tables.transactionItems} ti '
      'JOIN ${Tables.transactions} t ON t.id = ti.transaction_id '
      'WHERE t.status = ? '
      'ORDER BY ti.description ASC',
      [TransactionModel.recordedStatus],
    );
    return rows.map((r) => r['description'] as String).toList();
  }

  Future<List<String>> getImagePaths(String transactionId) async {
    final db = await _db.database;
    final rows = await db.query(
      Tables.transactionImages,
      columns: ['image_path'],
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
      orderBy: 'sort_order ASC',
    );
    return rows.map((r) => r['image_path'] as String).toList();
  }
}
