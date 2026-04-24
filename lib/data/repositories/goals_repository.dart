import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../database/tables.dart';
import '../models/goal_model.dart';

class GoalsRepository {
  const GoalsRepository(this._db);

  final DatabaseHelper _db;

  Future<List<GoalModel>> getAll({String? status}) async {
    final db = await _db.database;
    final rows = await db.query(
      Tables.goals,
      where: status != null ? 'status = ?' : null,
      whereArgs: status != null ? [status] : null,
      orderBy: 'created_at DESC',
    );
    return rows.map(GoalModel.fromMap).toList();
  }

  Future<List<GoalModel>> getForValue(String valueId) async {
    final db = await _db.database;
    final rows = await db.query(
      Tables.goals,
      where: 'value_id = ?',
      whereArgs: [valueId],
      orderBy: 'created_at DESC',
    );
    return rows.map(GoalModel.fromMap).toList();
  }

  Future<GoalModel?> getById(String id) async {
    final db = await _db.database;
    final rows = await db.query(
      Tables.goals,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return GoalModel.fromMap(rows.first);
  }

  Future<void> insert(GoalModel goal) async {
    final db = await _db.database;
    await db.insert(
      Tables.goals,
      goal.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(GoalModel goal) async {
    final db = await _db.database;
    await db.update(
      Tables.goals,
      goal.toMap(),
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete(Tables.goals, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateCurrentAmount(String id, int amount) async {
    final db = await _db.database;
    await db.update(
      Tables.goals,
      {'current_amount': amount},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
