import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/daily_intention_model.dart';
import '../shared/utils/date_utils.dart';
import '../shared/utils/id_generator.dart';
import 'database_provider.dart';

final dailyIntentionsProvider =
    AsyncNotifierProvider<DailyIntentionsNotifier, List<DailyIntentionModel>>(
      DailyIntentionsNotifier.new,
    );

class DailyIntentionsNotifier extends AsyncNotifier<List<DailyIntentionModel>> {
  @override
  Future<List<DailyIntentionModel>> build() async {
    return ref.watch(dailyIntentionsRepositoryProvider).getAll();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(dailyIntentionsRepositoryProvider).getAll(),
    );
  }

  Future<void> setIntention({
    required DateTime date,
    required String valueId,
  }) async {
    final repository = ref.read(dailyIntentionsRepositoryProvider);
    final normalized = AppDateUtils.startOfDay(date);
    final existing = await repository.getByDate(normalized);
    final now = DateTime.now();

    final intention =
        (existing ??
                DailyIntentionModel(
                  id: IdGenerator.generate(),
                  date: normalized,
                  valueId: valueId,
                  createdAt: now,
                ))
            .copyWith(date: normalized, valueId: valueId);

    await repository.upsert(intention);
    await refresh();
  }

  Future<void> saveReflection({
    required DailyIntentionModel intention,
    required String reflection,
  }) async {
    final updated = intention.copyWith(
      reflection: reflection.trim().isEmpty ? null : reflection.trim(),
      reflectedAt: reflection.trim().isEmpty ? null : DateTime.now(),
      clearReflection: reflection.trim().isEmpty,
      clearReflectedAt: reflection.trim().isEmpty,
    );
    await ref.read(dailyIntentionsRepositoryProvider).upsert(updated);
    await refresh();
  }
}

final todayIntentionProvider = Provider<DailyIntentionModel?>((ref) {
  final intentions = ref.watch(dailyIntentionsProvider).valueOrNull ?? [];
  final today = AppDateUtils.startOfDay(DateTime.now());
  return intentions
      .where((entry) => AppDateUtils.isSameDay(entry.date, today))
      .firstOrNull;
});

final yesterdayIntentionProvider = Provider<DailyIntentionModel?>((ref) {
  final intentions = ref.watch(dailyIntentionsProvider).valueOrNull ?? [];
  final yesterday = AppDateUtils.startOfDay(
    DateTime.now().subtract(const Duration(days: 1)),
  );
  return intentions
      .where((entry) => AppDateUtils.isSameDay(entry.date, yesterday))
      .firstOrNull;
});
