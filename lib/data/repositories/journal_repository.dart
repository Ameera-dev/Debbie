import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../database/tables.dart';
import '../models/journal_entry_model.dart';

class JournalRepository {
  const JournalRepository(this._db);

  final DatabaseHelper _db;

  Future<List<JournalEntryModel>> getAll() async {
    final db = await _db.database;
    final rows = await db.query(
      Tables.journal,
      orderBy: 'COALESCE(period_start, date) DESC, created_at DESC',
    );
    return rows.map(JournalEntryModel.fromMap).toList();
  }

  Future<JournalEntryModel?> getLatest() async {
    final db = await _db.database;
    final rows = await db.query(
      Tables.journal,
      orderBy: 'COALESCE(period_start, date) DESC, created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return JournalEntryModel.fromMap(rows.first);
  }

  Future<JournalEntryModel?> getById(String id) async {
    final db = await _db.database;
    final rows = await db.query(
      Tables.journal,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return JournalEntryModel.fromMap(rows.first);
  }

  Future<JournalEntryModel?> getWeeklyCheckInForPeriodStart(
    DateTime periodStart,
  ) {
    return getEntryByTypeAndPeriodStart(
      entryType: JournalEntryModel.weeklyCheckInType,
      periodStart: periodStart,
    );
  }

  Future<JournalEntryModel?> getEntryByTypeAndPeriodStart({
    required String entryType,
    required DateTime periodStart,
  }) async {
    final db = await _db.database;
    final rows = await db.query(
      Tables.journal,
      where: 'entry_type = ? AND period_start = ?',
      whereArgs: [
        entryType,
        DateTime(
          periodStart.year,
          periodStart.month,
          periodStart.day,
        ).toIso8601String(),
      ],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return JournalEntryModel.fromMap(rows.first);
  }

  Future<void> insert(JournalEntryModel entry) async {
    final db = await _db.database;
    await db.insert(
      Tables.journal,
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(JournalEntryModel entry) async {
    final db = await _db.database;
    await db.update(
      Tables.journal,
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete(Tables.journal, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateAiResponse(String id, String aiResponse) async {
    final db = await _db.database;
    await db.update(
      Tables.journal,
      {'ai_response': aiResponse},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
