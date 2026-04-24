import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../database/tables.dart';

class SettingsRepository {
  const SettingsRepository(this._db);

  final DatabaseHelper _db;

  Future<String?> get(String key) async {
    final db = await _db.database;
    final rows = await db.query(
      Tables.settings,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> set(String key, String value) async {
    final db = await _db.database;
    await db.insert(Tables.settings, {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> delete(String key) async {
    final db = await _db.database;
    await db.delete(Tables.settings, where: 'key = ?', whereArgs: [key]);
  }

  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final v = await get(key);
    if (v == null) return defaultValue;
    return v == 'true';
  }

  Future<void> setBool(String key, {required bool value}) =>
      set(key, value.toString());

  Future<int?> getInt(String key) async {
    final v = await get(key);
    return v != null ? int.tryParse(v) : null;
  }

  Future<void> setInt(String key, int value) => set(key, value.toString());
}
