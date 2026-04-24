import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/transaction_item_model.dart';
import '../data/models/transaction_model.dart';
import '../shared/utils/date_utils.dart';
import 'database_provider.dart';

final transactionsProvider =
    AsyncNotifierProvider<TransactionsNotifier, List<TransactionModel>>(
      TransactionsNotifier.new,
    );

class TransactionsNotifier extends AsyncNotifier<List<TransactionModel>> {
  @override
  Future<List<TransactionModel>> build() async {
    return ref.watch(transactionsRepositoryProvider).getAll();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(transactionsRepositoryProvider).getAll(),
    );
  }

  Future<void> addSession(
    TransactionModel session,
    List<TransactionItemModel> items,
  ) async {
    await ref
        .read(transactionsRepositoryProvider)
        .insertSession(session, items);
    ref.invalidate(pendingTransactionsProvider);
    await refresh();
  }

  Future<void> addPendingSession(
    TransactionModel session,
    List<TransactionItemModel> items,
  ) async {
    await ref
        .read(transactionsRepositoryProvider)
        .insertSession(session, items);
    ref.invalidate(pendingTransactionsProvider);
  }

  Future<void> editSession(
    TransactionModel session,
    List<TransactionItemModel> items,
  ) async {
    await ref
        .read(transactionsRepositoryProvider)
        .updateSession(session, items);
    ref.invalidate(pendingTransactionsProvider);
    await refresh();
  }

  Future<void> remove(String id) async {
    await ref.read(transactionsRepositoryProvider).delete(id);
    ref.invalidate(pendingTransactionsProvider);
    await refresh();
  }

  Future<void> confirmPending(String id) async {
    await ref.read(transactionsRepositoryProvider).confirmPending(id);
    ref.invalidate(pendingTransactionsProvider);
    await refresh();
  }

  Future<void> discardPending(String id) async {
    await ref.read(transactionsRepositoryProvider).delete(id);
    ref.invalidate(pendingTransactionsProvider);
  }
}

final pendingTransactionsProvider = FutureProvider<List<TransactionModel>>((
  ref,
) {
  return ref.read(transactionsRepositoryProvider).getPendingExpenses();
});

final duePendingTransactionsProvider = Provider<List<TransactionModel>>((ref) {
  final pending = ref.watch(pendingTransactionsProvider).valueOrNull ?? [];
  return pending.where((tx) => tx.isPendingReviewDue).toList();
});

final currentMonthTransactionsProvider = FutureProvider<List<TransactionModel>>(
  (ref) {
    ref.watch(transactionsProvider);
    final month = AppDateUtils.currentMonthKey();
    return ref.read(transactionsRepositoryProvider).getForMonth(month);
  },
);

/// Total income for the current month. Reacts to transaction changes.
final monthlyIncomeAmountProvider = FutureProvider<int>((ref) {
  ref.watch(transactionsProvider); // re-run when transactions mutate
  final month = AppDateUtils.currentMonthKey();
  return ref
      .read(transactionsRepositoryProvider)
      .getTotalForMonth(month, 'income');
});

/// Total expenses for the current month. Reacts to transaction changes.
final monthlyExpenseAmountProvider = FutureProvider<int>((ref) {
  ref.watch(transactionsProvider); // re-run when transactions mutate
  final month = AppDateUtils.currentMonthKey();
  return ref
      .read(transactionsRepositoryProvider)
      .getTotalForMonth(month, 'expense');
});

final spendingByValueProvider = FutureProvider<Map<String, int>>((ref) {
  ref.watch(transactionsProvider); // re-run when transactions mutate
  final month = AppDateUtils.currentMonthKey();
  return ref.read(transactionsRepositoryProvider).getSpendingByValue(month);
});

/// Today's transactions for the dashboard summary.
final todayTransactionsProvider = FutureProvider<List<TransactionModel>>((ref) {
  final all = ref.watch(transactionsProvider).valueOrNull ?? [];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return Future.value(
    all.where((tx) {
      final d = DateTime(tx.date.year, tx.date.month, tx.date.day);
      return d == today;
    }).toList(),
  );
});

/// Number of consecutive days (up to today) with at least one transaction.
final spendingStreakProvider = FutureProvider<int>((ref) {
  final all = ref.watch(transactionsProvider).valueOrNull ?? [];
  if (all.isEmpty) return Future.value(0);

  // Build a set of unique days
  final days = <DateTime>{};
  for (final tx in all) {
    days.add(DateTime(tx.date.year, tx.date.month, tx.date.day));
  }

  final now = DateTime.now();
  var day = DateTime(now.year, now.month, now.day);
  int streak = 0;

  // If nothing today, check if yesterday had something
  if (!days.contains(day)) {
    day = day.subtract(const Duration(days: 1));
  }

  while (days.contains(day)) {
    streak++;
    day = day.subtract(const Duration(days: 1));
  }

  return Future.value(streak);
});
