import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/goal_model.dart';
import 'database_provider.dart';

final goalsProvider = AsyncNotifierProvider<GoalsNotifier, List<GoalModel>>(
  GoalsNotifier.new,
);

class GoalsNotifier extends AsyncNotifier<List<GoalModel>> {
  @override
  Future<List<GoalModel>> build() async {
    return ref.watch(goalsRepositoryProvider).getAll();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(goalsRepositoryProvider).getAll(),
    );
  }

  Future<void> add(GoalModel goal) async {
    await ref.read(goalsRepositoryProvider).insert(goal);
    await refresh();
  }

  Future<void> edit(GoalModel goal) async {
    await ref.read(goalsRepositoryProvider).update(goal);
    await refresh();
  }

  Future<void> remove(String id) async {
    await ref.read(goalsRepositoryProvider).delete(id);
    await refresh();
  }
}

final activeGoalsProvider = FutureProvider<List<GoalModel>>((ref) {
  ref.watch(goalsProvider);
  return ref.watch(goalsRepositoryProvider).getAll(status: 'active');
});
