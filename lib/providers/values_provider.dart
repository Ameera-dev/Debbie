import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/value_model.dart';
import '../data/models/values_plan_model.dart';
import '../shared/utils/date_utils.dart';
import 'database_provider.dart';

final valuesProvider = AsyncNotifierProvider<ValuesNotifier, List<ValueModel>>(
  ValuesNotifier.new,
);

class ValuesNotifier extends AsyncNotifier<List<ValueModel>> {
  @override
  Future<List<ValueModel>> build() async {
    return ref.watch(valuesRepositoryProvider).getAll();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(valuesRepositoryProvider).getAll(),
    );
  }

  Future<void> insertAll(List<ValueModel> values) async {
    await ref.read(valuesRepositoryProvider).insertAll(values);
    await refresh();
  }

  Future<void> updatePriorities(List<String> orderedIds) async {
    await ref.read(valuesRepositoryProvider).updatePriorities(orderedIds);
    await refresh();
  }

  Future<void> updateGuardian(String valueId, String? guardianText) async {
    await ref
        .read(valuesRepositoryProvider)
        .updateGuardian(
          valueId,
          guardianText?.trim().isEmpty == true ? null : guardianText?.trim(),
        );
    await refresh();
  }

  Future<void> delete(String id) async {
    await ref.read(valuesRepositoryProvider).delete(id);
    await refresh();
  }
}

final valuesPlanProvider =
    AsyncNotifierProvider.family<
      ValuesPlanNotifier,
      List<ValuesPlanModel>,
      String
    >(ValuesPlanNotifier.new);

class ValuesPlanNotifier
    extends FamilyAsyncNotifier<List<ValuesPlanModel>, String> {
  @override
  Future<List<ValuesPlanModel>> build(String month) async {
    return ref.watch(valuesRepositoryProvider).getPlanForMonth(month);
  }

  Future<void> upsertAll(List<ValuesPlanModel> plans) async {
    await ref.read(valuesRepositoryProvider).upsertAllPlans(plans);
    state = AsyncValue.data(
      await ref.read(valuesRepositoryProvider).getPlanForMonth(arg),
    );
  }
}

final currentMonthPlanProvider =
    AsyncNotifierProvider<CurrentMonthPlanNotifier, List<ValuesPlanModel>>(
      CurrentMonthPlanNotifier.new,
    );

class CurrentMonthPlanNotifier extends AsyncNotifier<List<ValuesPlanModel>> {
  @override
  Future<List<ValuesPlanModel>> build() async {
    final month = AppDateUtils.currentMonthKey();
    return ref.watch(valuesRepositoryProvider).getPlanForMonth(month);
  }

  Future<void> upsertAll(List<ValuesPlanModel> plans) async {
    await ref.read(valuesRepositoryProvider).upsertAllPlans(plans);
    final month = AppDateUtils.currentMonthKey();
    state = AsyncValue.data(
      await ref.read(valuesRepositoryProvider).getPlanForMonth(month),
    );
  }
}
