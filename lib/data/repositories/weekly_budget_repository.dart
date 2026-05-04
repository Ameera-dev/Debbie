import 'package:sqflite/sqflite.dart';

import '../../shared/utils/date_utils.dart';
import '../database/database_helper.dart';
import '../database/tables.dart';
import '../models/weekly_budget_plan_model.dart';

class WeeklyBudgetRepository {
  const WeeklyBudgetRepository(this._db);

  final DatabaseHelper _db;

  /// Fetch all plans whose date falls inside [start, end] (inclusive).
  Future<List<WeeklyBudgetPlanModel>> getRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await _db.database;
    final from = AppDateUtils.startOfDay(start);
    final to = AppDateUtils.startOfDay(end);
    final rows = await db.query(
      Tables.weeklyBudgetPlans,
      where: 'plan_date >= ? AND plan_date <= ?',
      whereArgs: [from.toIso8601String(), to.toIso8601String()],
      orderBy: 'plan_date ASC',
    );
    return rows.map(WeeklyBudgetPlanModel.fromMap).toList();
  }

  Future<List<WeeklyBudgetPlanModel>> getForWeek(DateTime weekStart) async {
    final db = await _db.database;
    final start = AppDateUtils.startOfDay(weekStart);
    final end = start.add(const Duration(days: 6));
    final rows = await db.query(
      Tables.weeklyBudgetPlans,
      where: 'plan_date >= ? AND plan_date <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'plan_date ASC',
    );
    return rows.map(WeeklyBudgetPlanModel.fromMap).toList();
  }

  Future<void> upsertMany(List<WeeklyBudgetPlanModel> plans) async {
    final db = await _db.database;
    final batch = db.batch();
    for (final plan in plans) {
      batch.insert(
        Tables.weeklyBudgetPlans,
        plan.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> upsert(WeeklyBudgetPlanModel plan) async {
    final db = await _db.database;
    await db.insert(
      Tables.weeklyBudgetPlans,
      plan.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(WeeklyBudgetPlanModel plan) async {
    final db = await _db.database;
    await db.update(
      Tables.weeklyBudgetPlans,
      plan.toMap(),
      where: 'id = ?',
      whereArgs: [plan.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete(
      Tables.weeklyBudgetPlans,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Find a plan that already exists on the same date (if any).
  Future<WeeklyBudgetPlanModel?> findByDate(DateTime date) async {
    final db = await _db.database;
    final start = AppDateUtils.startOfDay(date);
    final rows = await db.query(
      Tables.weeklyBudgetPlans,
      where: 'plan_date = ?',
      whereArgs: [start.toIso8601String()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return WeeklyBudgetPlanModel.fromMap(rows.first);
  }
}
