import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../database/tables.dart';
import '../models/value_model.dart';
import '../models/values_plan_model.dart';

class ValuesRepository {
  const ValuesRepository(this._db);

  final DatabaseHelper _db;

  Future<List<ValueModel>> getAll() async {
    final db = await _db.database;
    final rows = await db.query(Tables.userValues, orderBy: 'priority ASC');
    return rows.map(ValueModel.fromMap).toList();
  }

  Future<ValueModel?> getById(String id) async {
    final db = await _db.database;
    final rows = await db.query(
      Tables.userValues,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ValueModel.fromMap(rows.first);
  }

  Future<void> insert(ValueModel value) async {
    final db = await _db.database;
    await db.insert(
      Tables.userValues,
      value.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertAll(List<ValueModel> values) async {
    final db = await _db.database;
    final batch = db.batch();
    for (final v in values) {
      batch.insert(
        Tables.userValues,
        v.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> update(ValueModel value) async {
    final db = await _db.database;
    await db.update(
      Tables.userValues,
      value.toMap(),
      where: 'id = ?',
      whereArgs: [value.id],
    );
  }

  Future<void> updateGuardian(String id, String? guardianText) async {
    final db = await _db.database;
    await db.update(
      Tables.userValues,
      {'guardian_text': guardianText},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete(Tables.userValues, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updatePriorities(List<String> orderedIds) async {
    final db = await _db.database;
    final batch = db.batch();
    for (var i = 0; i < orderedIds.length; i++) {
      batch.update(
        Tables.userValues,
        {'priority': i},
        where: 'id = ?',
        whereArgs: [orderedIds[i]],
      );
    }
    await batch.commit(noResult: true);
  }

  // --- Values Plan ---

  Future<List<ValuesPlanModel>> getPlanForMonth(String month) async {
    final db = await _db.database;
    final rows = await db.query(
      Tables.valuesPlan,
      where: 'month = ?',
      whereArgs: [month],
    );
    return rows.map(ValuesPlanModel.fromMap).toList();
  }

  Future<void> upsertPlan(ValuesPlanModel plan) async {
    final db = await _db.database;
    await db.insert(
      Tables.valuesPlan,
      plan.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertAllPlans(List<ValuesPlanModel> plans) async {
    final db = await _db.database;
    final batch = db.batch();
    for (final p in plans) {
      batch.insert(
        Tables.valuesPlan,
        p.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }
}
