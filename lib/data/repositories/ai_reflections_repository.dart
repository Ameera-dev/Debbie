import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../database/tables.dart';
import '../models/ai_reflection_model.dart';

class AiReflectionsRepository {
  const AiReflectionsRepository(this._db);

  final DatabaseHelper _db;

  Future<List<AiReflectionModel>> getAll() async {
    final db = await _db.database;
    final rows = await db.query(
      Tables.aiReflections,
      orderBy: 'date DESC, created_at DESC',
    );
    return rows.map(AiReflectionModel.fromMap).toList();
  }

  Future<AiReflectionModel?> getLatestByType(String type) async {
    final db = await _db.database;
    final rows = await db.query(
      Tables.aiReflections,
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'date DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AiReflectionModel.fromMap(rows.first);
  }

  Future<void> insert(AiReflectionModel reflection) async {
    final db = await _db.database;
    await db.insert(
      Tables.aiReflections,
      reflection.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete(Tables.aiReflections, where: 'id = ?', whereArgs: [id]);
  }
}
