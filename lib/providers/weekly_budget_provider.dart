import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/weekly_budget_plan_model.dart';
import '../shared/utils/date_utils.dart';
import '../shared/utils/id_generator.dart';
import 'database_provider.dart';

final weeklyBudgetPlansProvider =
    AsyncNotifierProvider<
      WeeklyBudgetPlansNotifier,
      List<WeeklyBudgetPlanModel>
    >(WeeklyBudgetPlansNotifier.new);

/// One aggregated data point per week for the performance line chart.
class WeeklyPerformancePoint {
  const WeeklyPerformancePoint({
    required this.weekStart,
    required this.plannedTotal,
    required this.actualTotal,
    required this.actualizedDays,
  });

  final DateTime weekStart;
  final int plannedTotal;
  final int actualTotal;
  final int actualizedDays;

  /// (planned - actual) / planned * 100. Null when no actualized days.
  double? get performancePercent {
    if (actualizedDays == 0 || plannedTotal <= 0) return null;
    return ((plannedTotal - actualTotal) / plannedTotal) * 100;
  }
}

/// Returns the last [weeks] weeks (oldest → newest) of weekly performance.
/// Only weeks that have at least one actualized day are included.
final weeklyPerformanceHistoryProvider =
    FutureProvider.family<List<WeeklyPerformancePoint>, int>((ref, weeks) async {
  // Re-fetch when current-week plans change (so the latest week stays fresh).
  ref.watch(weeklyBudgetPlansProvider);

  final repo = ref.watch(weeklyBudgetRepositoryProvider);
  final today = AppDateUtils.startOfDay(DateTime.now());
  final currentWeekStart = AppDateUtils.startOfWeek(today);
  final earliestWeekStart =
      currentWeekStart.subtract(Duration(days: 7 * (weeks - 1)));
  final latestDay = currentWeekStart.add(const Duration(days: 6));

  final plans = await repo.getRange(earliestWeekStart, latestDay);

  final byWeek = <DateTime, List<WeeklyBudgetPlanModel>>{};
  for (final plan in plans) {
    final weekStart = AppDateUtils.startOfWeek(plan.date);
    byWeek.putIfAbsent(weekStart, () => []).add(plan);
  }

  final points = <WeeklyPerformancePoint>[];
  for (int i = 0; i < weeks; i++) {
    final weekStart =
        earliestWeekStart.add(Duration(days: 7 * i));
    final weekPlans = byWeek[weekStart] ?? const [];
    final actualized =
        weekPlans.where((p) => p.isActualized).toList();
    if (actualized.isEmpty) continue;
    final plannedTotal =
        actualized.fold<int>(0, (s, p) => s + p.plannedAmount);
    final actualTotal =
        actualized.fold<int>(0, (s, p) => s + (p.actualAmount ?? 0));
    points.add(WeeklyPerformancePoint(
      weekStart: weekStart,
      plannedTotal: plannedTotal,
      actualTotal: actualTotal,
      actualizedDays: actualized.length,
    ));
  }
  return points;
});

class WeeklyBudgetPlansNotifier
    extends AsyncNotifier<List<WeeklyBudgetPlanModel>> {
  @override
  Future<List<WeeklyBudgetPlanModel>> build() {
    final weekStart = AppDateUtils.startOfWeek(DateTime.now());
    return ref.watch(weeklyBudgetRepositoryProvider).getForWeek(weekStart);
  }

  Future<void> refresh() async {
    final weekStart = AppDateUtils.startOfWeek(DateTime.now());
    state = await AsyncValue.guard(
      () => ref.read(weeklyBudgetRepositoryProvider).getForWeek(weekStart),
    );
  }

  Future<void> createWeekPlan({
    required DateTime weekStart,
    required int dailyLimit,
  }) async {
    final normalizedStart = AppDateUtils.startOfWeek(weekStart);
    final existing =
        state.valueOrNull ??
        await ref
            .read(weeklyBudgetRepositoryProvider)
            .getForWeek(normalizedStart);
    final existingByDate = {
      for (final plan in existing) AppDateUtils.startOfDay(plan.date): plan,
    };
    final now = DateTime.now();

    final plans = List.generate(7, (index) {
      final date = normalizedStart.add(Duration(days: index));
      final existingPlan = existingByDate[date];
      return WeeklyBudgetPlanModel(
        id: existingPlan?.id ?? IdGenerator.generate(),
        date: date,
        plannedAmount: dailyLimit,
        actualAmount: existingPlan?.actualAmount,
        notes: existingPlan?.notes,
        actualizedAt: existingPlan?.actualizedAt,
        createdAt: existingPlan?.createdAt ?? now,
      );
    });

    await ref.read(weeklyBudgetRepositoryProvider).upsertMany(plans);
    state = AsyncValue.data(plans);
  }

  Future<void> actualize({
    required WeeklyBudgetPlanModel plan,
    required int actualAmount,
    String? notes,
  }) async {
    final updated = plan.copyWith(
      actualAmount: actualAmount,
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      actualizedAt: DateTime.now(),
      clearNotes: notes?.trim().isEmpty == true,
    );
    await ref.read(weeklyBudgetRepositoryProvider).update(updated);
    await refresh();
  }

  /// Add or update a single plan for a specific date.
  /// If a plan already exists for the date, its planned amount is updated.
  Future<void> addPlanForDate({
    required DateTime date,
    required int plannedAmount,
    String? notes,
  }) async {
    final repo = ref.read(weeklyBudgetRepositoryProvider);
    final existing = await repo.findByDate(date);
    final now = DateTime.now();

    final plan = existing != null
        ? existing.copyWith(
            plannedAmount: plannedAmount,
            notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
            clearNotes: notes?.trim().isEmpty == true,
          )
        : WeeklyBudgetPlanModel(
            id: IdGenerator.generate(),
            date: AppDateUtils.startOfDay(date),
            plannedAmount: plannedAmount,
            notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
            createdAt: now,
          );

    await repo.upsert(plan);
    await refresh();
  }

  /// Delete a plan entirely.
  Future<void> removePlan(String id) async {
    await ref.read(weeklyBudgetRepositoryProvider).delete(id);
    await refresh();
  }
}
