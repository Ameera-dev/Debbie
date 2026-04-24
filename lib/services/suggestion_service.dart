import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/database_helper.dart';
import '../data/database/tables.dart';
import '../providers/database_provider.dart';

/// Suggests a value ID for a new transaction item based on past entries
/// with the same or similar description.
class SuggestionService {
  const SuggestionService(this._db);

  final DatabaseHelper _db;

  /// Returns the most frequently used value_id for items whose description
  /// matches [description] (case-insensitive exact match first, then LIKE).
  /// Returns null if no match is found.
  Future<String?> suggestValueId(String description) async {
    final trimmed = description.trim();
    if (trimmed.isEmpty) return null;

    final db = await _db.database;

    // Exact match (case-insensitive) — most reliable signal
    var rows = await db.rawQuery(
      '''
      SELECT value_id, COUNT(*) AS cnt
      FROM ${Tables.transactionItems}
      WHERE value_id IS NOT NULL
        AND LOWER(description) = LOWER(?)
      GROUP BY value_id
      ORDER BY cnt DESC
      LIMIT 1
      ''',
      [trimmed],
    );

    if (rows.isNotEmpty) {
      return rows.first['value_id'] as String?;
    }

    // Fuzzy fallback — description contains the query or vice versa
    rows = await db.rawQuery(
      '''
      SELECT value_id, COUNT(*) AS cnt
      FROM ${Tables.transactionItems}
      WHERE value_id IS NOT NULL
        AND (LOWER(description) LIKE LOWER(?) OR LOWER(?) LIKE '%' || LOWER(description) || '%')
      GROUP BY value_id
      ORDER BY cnt DESC
      LIMIT 1
      ''',
      ['%$trimmed%', trimmed],
    );

    if (rows.isNotEmpty) {
      return rows.first['value_id'] as String?;
    }

    return null;
  }

  /// Returns the most frequently used goal_id for items with a given
  /// value_id and similar description. Returns null if no match.
  Future<String?> suggestGoalId(String description, String valueId) async {
    final trimmed = description.trim();
    if (trimmed.isEmpty) return null;

    final db = await _db.database;
    final rows = await db.rawQuery(
      '''
      SELECT ti.goal_id, COUNT(*) AS cnt
      FROM ${Tables.transactionItems} ti
      WHERE ti.goal_id IS NOT NULL
        AND ti.value_id = ?
        AND LOWER(ti.description) = LOWER(?)
      GROUP BY ti.goal_id
      ORDER BY cnt DESC
      LIMIT 1
      ''',
      [valueId, trimmed],
    );

    if (rows.isNotEmpty) {
      return rows.first['goal_id'] as String?;
    }
    return null;
  }
}

final suggestionServiceProvider = Provider<SuggestionService>((ref) {
  return SuggestionService(ref.watch(databaseHelperProvider));
});
