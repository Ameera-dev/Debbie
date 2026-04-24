import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/database_helper.dart';
import '../data/repositories/ai_reflections_repository.dart';
import '../data/repositories/daily_intentions_repository.dart';
import '../data/repositories/goals_repository.dart';
import '../data/repositories/journal_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/transactions_repository.dart';
import '../data/repositories/values_repository.dart';

final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper.instance;
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(databaseHelperProvider));
});

final valuesRepositoryProvider = Provider<ValuesRepository>((ref) {
  return ValuesRepository(ref.watch(databaseHelperProvider));
});

final transactionsRepositoryProvider = Provider<TransactionsRepository>((ref) {
  return TransactionsRepository(ref.watch(databaseHelperProvider));
});

final goalsRepositoryProvider = Provider<GoalsRepository>((ref) {
  return GoalsRepository(ref.watch(databaseHelperProvider));
});

final journalRepositoryProvider = Provider<JournalRepository>((ref) {
  return JournalRepository(ref.watch(databaseHelperProvider));
});

final dailyIntentionsRepositoryProvider = Provider<DailyIntentionsRepository>((
  ref,
) {
  return DailyIntentionsRepository(ref.watch(databaseHelperProvider));
});

final aiReflectionsRepositoryProvider = Provider<AiReflectionsRepository>((
  ref,
) {
  return AiReflectionsRepository(ref.watch(databaseHelperProvider));
});
