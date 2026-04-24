import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../database/tables.dart';
import '../models/daily_intention_model.dart';

class DailyIntentionsRepository {
  const DailyIntentionsRepository(this._db);

  final DatabaseHelper _db;

  Future<List<DailyIntentionModel>> getAll() async {
    final db = await _db.database;
    final rows = await db.query(
      Tables.dailyIntentions,
      orderBy: 'date DESC, created_at DESC',
    );
    return rows.map(DailyIntentionModel.fromMap).toList();
  }

  Future<DailyIntentionModel?> getByDate(DateTime date) async {
    final db = await _db.database;
    final normalized = DateTime(date.year, date.month, date.day);
    final rows = await db.query(
      Tables.dailyIntentions,
      where: 'date = ?',
      whereArgs: [normalized.toIso8601String()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DailyIntentionModel.fromMap(rows.first);
  }

  Future<void> upsert(DailyIntentionModel intention) async {
    final db = await _db.database;
    await db.insert(
      Tables.dailyIntentions,
      intention.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete(Tables.dailyIntentions, where: 'id = ?', whereArgs: [id]);
  }
}
