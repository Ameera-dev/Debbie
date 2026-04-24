import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/goals_repository.dart';
import '../data/repositories/transactions_repository.dart';
import '../data/repositories/values_repository.dart';
import '../providers/database_provider.dart';
import '../shared/constants/strings.dart';
import '../shared/utils/date_utils.dart';

// ---------------------------------------------------------------------------
// MonthlyInsight data class
// ---------------------------------------------------------------------------

class GoalSummary {
  const GoalSummary({required this.title, required this.progressPercent});

  final String title;
  final double? progressPercent;
}

class MonthlyInsight {
  const MonthlyInsight({
    this.topValueName,
    this.topValueIcon,
    this.topValueAmount = 0,
    this.mostImprovedValueName,
    this.goalSummaries = const [],
    required this.closingMessage,
  });

  final String? topValueName;
  final String? topValueIcon;
  final int topValueAmount;
  final String? mostImprovedValueName;
  final List<GoalSummary> goalSummaries;
  final String closingMessage;

  bool get hasData => topValueName != null;
}

// ---------------------------------------------------------------------------
// InsightsService
// ---------------------------------------------------------------------------

class InsightsService {
  const InsightsService({
    required this.transactionsRepo,
    required this.valuesRepo,
    required this.goalsRepo,
  });

  final TransactionsRepository transactionsRepo;
  final ValuesRepository valuesRepo;
  final GoalsRepository goalsRepo;

  Future<MonthlyInsight> generateMonthlyInsight(String month) async {
    final values = await valuesRepo.getAll();
    if (values.isEmpty) {
      return MonthlyInsight(closingMessage: _randomClosingMessage());
    }

    final valueMap = {for (final v in values) v.id: v};

    // Current month spending by value
    final spending = await transactionsRepo.getSpendingByValue(month);

    // Previous month spending by value
    final prevMonth = AppDateUtils.previousMonthKey(
      DateTime.parse('$month-01'),
    );
    final prevSpending = await transactionsRepo.getSpendingByValue(prevMonth);

    // Top value
    String? topValueName;
    String? topValueIcon;
    int topValueAmount = 0;
    if (spending.isNotEmpty) {
      final topEntry = spending.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );
      final topValue = valueMap[topEntry.key];
      topValueName = topValue?.name;
      topValueIcon = topValue?.icon;
      topValueAmount = topEntry.value;
    }

    // Most improved: biggest positive share change
    String? mostImproved;
    if (spending.isNotEmpty && prevSpending.isNotEmpty) {
      final totalCurrent = spending.values.fold<int>(0, (s, v) => s + v);
      final totalPrev = prevSpending.values.fold<int>(0, (s, v) => s + v);

      if (totalCurrent > 0 && totalPrev > 0) {
        double bestDelta = 0;
        String? bestId;
        for (final entry in spending.entries) {
          final currentShare = entry.value / totalCurrent;
          final prevShare = (prevSpending[entry.key] ?? 0) / totalPrev;
          final delta = currentShare - prevShare;
          if (delta > bestDelta) {
            bestDelta = delta;
            bestId = entry.key;
          }
        }
        if (bestId != null && bestDelta > 0.01) {
          mostImproved = valueMap[bestId]?.name;
        }
      }
    }

    // Goal summaries
    final activeGoals = await goalsRepo.getAll(status: 'active');
    final goalSummaries = activeGoals.map((g) {
      return GoalSummary(title: g.title, progressPercent: g.progressPercent);
    }).toList();

    return MonthlyInsight(
      topValueName: topValueName,
      topValueIcon: topValueIcon,
      topValueAmount: topValueAmount,
      mostImprovedValueName: mostImproved,
      goalSummaries: goalSummaries,
      closingMessage: _randomClosingMessage(),
    );
  }

  static String _randomClosingMessage() {
    const messages = AppStrings.encouragingMessages;
    return messages[Random().nextInt(messages.length)];
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final insightsServiceProvider = Provider<InsightsService>((ref) {
  return InsightsService(
    transactionsRepo: ref.watch(transactionsRepositoryProvider),
    valuesRepo: ref.watch(valuesRepositoryProvider),
    goalsRepo: ref.watch(goalsRepositoryProvider),
  );
});

final monthlyInsightProvider = FutureProvider<MonthlyInsight>((ref) {
  final service = ref.watch(insightsServiceProvider);
  final month = AppDateUtils.currentMonthKey();
  return service.generateMonthlyInsight(month);
});
