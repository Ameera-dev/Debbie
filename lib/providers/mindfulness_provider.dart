import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'daily_intentions_provider.dart';
import 'journal_provider.dart';
import 'transactions_provider.dart';
import '../shared/utils/date_utils.dart';

final awarenessStreakProvider = Provider<int>((ref) {
  final transactions = ref.watch(transactionsProvider).valueOrNull ?? [];
  final journalEntries = ref.watch(journalProvider).valueOrNull ?? [];
  final intentions = ref.watch(dailyIntentionsProvider).valueOrNull ?? [];

  final mindfulDays = <DateTime>{};

  for (final tx in transactions) {
    if (tx.notes?.trim().isNotEmpty == true) {
      mindfulDays.add(AppDateUtils.startOfDay(tx.date));
    }
  }

  for (final entry in journalEntries) {
    if (entry.content.trim().isNotEmpty) {
      mindfulDays.add(AppDateUtils.startOfDay(entry.date));
    }
  }

  for (final intention in intentions) {
    if (intention.hasReflection) {
      mindfulDays.add(AppDateUtils.startOfDay(intention.date));
    }
  }

  if (mindfulDays.isEmpty) return 0;

  var day = AppDateUtils.startOfDay(DateTime.now());
  var streak = 0;

  if (!mindfulDays.contains(day)) {
    day = day.subtract(const Duration(days: 1));
  }

  while (mindfulDays.contains(day)) {
    streak++;
    day = day.subtract(const Duration(days: 1));
  }

  return streak;
});
